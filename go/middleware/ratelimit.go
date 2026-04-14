package middleware

import (
	"fmt"
	"log/slog"
	"math"
	"net"
	"net/http"
	"os"
	"strconv"
	"sync"
	"time"
)

// SECURITY LESSON: Rate limiting — Without rate limiting, a single client can
// overwhelm your server with requests (Denial of Service). A token bucket
// algorithm allows short bursts (normal user behavior) while capping sustained
// throughput.
//
// Per-user rate limiting means authenticated users get their own bucket. This
// prevents one abusive user from consuming another user's quota, and avoids
// penalizing all users behind a shared NAT/VPN (same IP). Unauthenticated
// requests fall back to per-IP limiting.

// tokenBucket implements a simple token bucket rate limiter.
// Tokens refill at a fixed rate (rps). The bucket holds up to burst tokens.
// Each request consumes one token. If the bucket is empty, the request is denied.
type tokenBucket struct {
	mu       sync.Mutex
	tokens   float64
	max      float64 // burst capacity
	rate     float64 // tokens per second
	lastTime time.Time
	lastSeen time.Time // for cleanup of stale entries
}

func newTokenBucket(rate float64, burst int) *tokenBucket {
	return &tokenBucket{
		tokens:   float64(burst),
		max:      float64(burst),
		rate:     rate,
		lastTime: time.Now(),
		lastSeen: time.Now(),
	}
}

// allow checks if a request is permitted and consumes a token if so.
// Returns true if allowed, false if rate limited.
func (tb *tokenBucket) allow() bool {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(tb.lastTime).Seconds()
	tb.lastTime = now
	tb.lastSeen = now

	// Refill tokens based on elapsed time
	tb.tokens += elapsed * tb.rate
	if tb.tokens > tb.max {
		tb.tokens = tb.max
	}

	if tb.tokens < 1.0 {
		return false
	}

	tb.tokens--
	return true
}

// retryAfter returns how many seconds until at least 1 token is available.
func (tb *tokenBucket) retryAfter() int {
	tb.mu.Lock()
	defer tb.mu.Unlock()

	if tb.tokens >= 1.0 {
		return 0
	}

	deficit := 1.0 - tb.tokens
	seconds := deficit / tb.rate
	return int(math.Ceil(seconds))
}

// keyLimiter manages per-key (user or IP) token buckets.
type keyLimiter struct {
	buckets sync.Map // string (key) -> *tokenBucket
	rate    float64
	burst   int
}

func newKeyLimiter(rate float64, burst int) *keyLimiter {
	return &keyLimiter{
		rate:  rate,
		burst: burst,
	}
}

// getBucket returns the token bucket for the given key, creating one if needed.
func (l *keyLimiter) getBucket(key string) *tokenBucket {
	if val, ok := l.buckets.Load(key); ok {
		return val.(*tokenBucket)
	}

	bucket := newTokenBucket(l.rate, l.burst)
	actual, _ := l.buckets.LoadOrStore(key, bucket)
	return actual.(*tokenBucket)
}

// cleanup removes stale entries that haven't been seen in the given duration.
func (l *keyLimiter) cleanup(staleDuration time.Duration) {
	cutoff := time.Now().Add(-staleDuration)
	count := 0
	l.buckets.Range(func(key, value any) bool {
		bucket := value.(*tokenBucket)
		bucket.mu.Lock()
		lastSeen := bucket.lastSeen
		bucket.mu.Unlock()
		if lastSeen.Before(cutoff) {
			l.buckets.Delete(key)
			count++
		}
		return true
	})
	if count > 0 {
		slog.Info("rate limiter cleanup", "removed_entries", count)
	}
}

// rateLimitKey determines the key for rate limiting: "user:<sub>" if
// authenticated, "ip:<addr>" otherwise.
//
// SECURITY LESSON: Per-user rate limiting is fairer and more precise. Without
// it, all users behind a corporate NAT share one bucket, and one abusive user
// can lock out an entire office. Per-user limits isolate quotas. We fall back
// to IP for unauthenticated endpoints (login, healthz, etc.).
func rateLimitKey(r *http.Request) string {
	// Check if auth middleware has placed a user in the request context.
	if user := UserFromContext(r.Context()); user != nil && user.Subject != "" {
		return "user:" + user.Subject
	}

	// Fallback to per-IP when no authenticated user is available.
	return "ip:" + extractIP(r)
}

// RateLimit returns middleware that enforces per-user (or per-IP) rate limiting.
// Configuration is read from environment variables:
//   - RATE_LIMIT_RPS: requests per second (default: 10)
//   - RATE_LIMIT_BURST: burst capacity (default: 20)
//
// Returns 429 Too Many Requests with a Retry-After header when exceeded.
func RateLimit(next http.Handler) http.Handler {
	rps := 10.0
	burst := 20

	if v := os.Getenv("RATE_LIMIT_RPS"); v != "" {
		if parsed, err := strconv.ParseFloat(v, 64); err == nil && parsed > 0 {
			rps = parsed
		}
	}

	if v := os.Getenv("RATE_LIMIT_BURST"); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil && parsed > 0 {
			burst = parsed
		}
	}

	limiter := newKeyLimiter(rps, burst)

	// SECURITY LESSON: Stale entry cleanup — Without this, the sync.Map grows
	// unbounded as new keys arrive. An attacker could exhaust server memory by
	// sending requests from many spoofed IPs. Periodic cleanup prevents this.
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			limiter.cleanup(10 * time.Minute)
		}
	}()

	slog.Info("rate limiter configured", "rps", rps, "burst", burst)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		key := rateLimitKey(r)
		bucket := limiter.getBucket(key)

		if !bucket.allow() {
			retryAfter := bucket.retryAfter()
			w.Header().Set("Retry-After", fmt.Sprintf("%d", retryAfter))
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusTooManyRequests)
			w.Write([]byte(`{"error":"rate limit exceeded"}`))
			slog.Warn("rate limit exceeded",
				"key", key,
				"path", r.URL.Path,
				"retry_after", retryAfter,
			)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// extractIP gets the client IP from the request.
// In production behind a reverse proxy, you would check X-Forwarded-For or
// X-Real-IP — but only if you trust the proxy. Here we use RemoteAddr as the
// safe default. The proxy configuration should be handled at the infrastructure
// level (Traefik sets these headers).
func extractIP(r *http.Request) string {
	// Check X-Real-IP first (set by trusted reverse proxies like Traefik)
	if ip := r.Header.Get("X-Real-IP"); ip != "" {
		return ip
	}

	// Fall back to RemoteAddr (which includes port)
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return ip
}
