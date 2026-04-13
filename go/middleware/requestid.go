package middleware

import (
	"context"
	"crypto/rand"
	"fmt"
	"log/slog"
	"net/http"
)

// SECURITY LESSON: Request IDs — Every request gets a unique identifier that
// flows through logs, responses, and downstream services. When something goes
// wrong, you can trace a single request across your entire system. Without
// request IDs, debugging production issues means grepping timestamps and hoping.
// If the incoming request already has an X-Request-ID (from an upstream service
// or API gateway), we propagate it to maintain the trace across service boundaries.

const (
	// RequestIDHeader is the standard header for request tracing.
	RequestIDHeader = "X-Request-ID"
)

type requestIDKey struct{}

// RequestIDFromContext extracts the request ID from the context.
func RequestIDFromContext(ctx context.Context) string {
	id, _ := ctx.Value(requestIDKey{}).(string)
	return id
}

// RequestID is middleware that assigns a unique ID to every request.
// If the incoming request already carries an X-Request-ID header, that value
// is propagated. Otherwise, a new UUID v4 is generated.
// The ID is stored in the request context and set as a response header.
func RequestID(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		id := r.Header.Get(RequestIDHeader)
		if id == "" {
			id = generateUUIDv4()
		}

		// Set on response so the caller can correlate
		w.Header().Set(RequestIDHeader, id)

		// Store in context for downstream handlers and logging
		ctx := context.WithValue(r.Context(), requestIDKey{}, id)

		slog.Info("request started",
			"request_id", id,
			"method", r.Method,
			"path", r.URL.Path,
			"remote_addr", r.RemoteAddr,
		)

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// generateUUIDv4 creates a RFC 4122 version 4 UUID using crypto/rand.
// SECURITY LESSON: We use crypto/rand, not math/rand, because UUIDs used in
// security contexts (request tracing, session IDs) must be unpredictable.
// math/rand is deterministic given the seed — an attacker could predict future
// values. crypto/rand reads from the OS CSPRNG (/dev/urandom on Linux).
func generateUUIDv4() string {
	var uuid [16]byte
	_, err := rand.Read(uuid[:])
	if err != nil {
		// crypto/rand.Read failing means the OS entropy source is broken.
		// This is catastrophic — panic rather than generate predictable IDs.
		panic(fmt.Sprintf("crypto/rand.Read failed: %v", err))
	}

	// Set version 4 (bits 12-15 of time_hi_and_version)
	uuid[6] = (uuid[6] & 0x0f) | 0x40
	// Set variant to RFC 4122 (bits 6-7 of clk_seq_hi_res)
	uuid[8] = (uuid[8] & 0x3f) | 0x80

	return fmt.Sprintf("%08x-%04x-%04x-%04x-%012x",
		uuid[0:4],
		uuid[4:6],
		uuid[6:8],
		uuid[8:10],
		uuid[10:16],
	)
}
