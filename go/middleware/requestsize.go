package middleware

import (
	"log/slog"
	"net/http"
	"os"
	"strconv"
)

// SECURITY LESSON: Request size limits — Without a cap on request body size,
// an attacker can send a multi-gigabyte POST body and exhaust your server's
// memory (memory exhaustion / resource exhaustion attack). http.MaxBytesReader
// wraps the body and returns an error once the limit is exceeded, preventing
// the entire body from being read into memory. This is defense-in-depth:
// even if the reverse proxy has its own limit, the application should enforce
// its own to avoid depending on infrastructure configuration.

const (
	// defaultMaxRequestBytes is 1MB — sufficient for most JSON API payloads.
	defaultMaxRequestBytes int64 = 1 << 20
)

// MaxRequestSize returns middleware that limits the request body to maxBytes.
// If maxBytes is 0, it reads from the MAX_REQUEST_BODY_BYTES env var,
// defaulting to 1MB.
// Returns 413 Payload Too Large when the body exceeds the limit.
func MaxRequestSize(maxBytes int64, next http.Handler) http.Handler {
	if maxBytes <= 0 {
		maxBytes = defaultMaxRequestBytes
		if v := os.Getenv("MAX_REQUEST_BODY_BYTES"); v != "" {
			if parsed, err := strconv.ParseInt(v, 10, 64); err == nil && parsed > 0 {
				maxBytes = parsed
			}
		}
	}

	slog.Info("request size limit configured", "max_bytes", maxBytes)

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// SECURITY LESSON: http.MaxBytesReader is Go's built-in defense against
		// oversized request bodies. It wraps r.Body so that any read beyond the
		// limit returns an error. The http.Server then automatically returns
		// 413 if the handler tries to read beyond the limit. We also set it
		// explicitly here for handlers that read the body themselves.
		r.Body = http.MaxBytesReader(w, r.Body, maxBytes)

		next.ServeHTTP(w, r)
	})
}

// RequestSizeMiddleware is a convenience wrapper that reads the limit from
// the environment and applies it as middleware. Use this when wiring the
// handler chain in main.go.
func RequestSizeMiddleware(next http.Handler) http.Handler {
	return MaxRequestSize(0, next)
}
