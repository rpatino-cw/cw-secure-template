package middleware

import (
	"log/slog"
	"net/http"
	"time"
)

// AuditLog returns middleware that logs a structured audit trail entry for every
// request. Each entry includes user_id, action (method), resource (path),
// status code, duration, client IP, request ID, and timestamp.
//
// When auth middleware has run, the user is extracted from context. Otherwise
// the entry logs "anonymous" — this is expected for unauthenticated endpoints
// like /healthz.
func AuditLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Wrap ResponseWriter to capture the status code.
		sw := &statusWriter{ResponseWriter: w, status: http.StatusOK}

		next.ServeHTTP(sw, r)

		duration := time.Since(start)

		// Extract user from context (set by RequireAuth middleware).
		userID := "anonymous"
		if user := UserFromContext(r.Context()); user != nil {
			userID = user.Subject
		}

		// Extract request ID from context (set by RequestID middleware).
		requestID := RequestIDFromContext(r.Context())

		// Client IP for audit trail.
		clientIP := extractIP(r)

		slog.Info("audit",
			"user_id", userID,
			"action", r.Method,
			"resource", r.URL.Path,
			"query", r.URL.RawQuery,
			"status_code", sw.status,
			"duration_ms", duration.Milliseconds(),
			"client_ip", clientIP,
			"request_id", requestID,
			"timestamp", start.UTC().Format(time.RFC3339),
			"user_agent", r.UserAgent(),
		)
	})
}

// statusWriter wraps http.ResponseWriter to capture the response status code.
type statusWriter struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func (w *statusWriter) WriteHeader(code int) {
	if !w.wroteHeader {
		w.status = code
		w.wroteHeader = true
	}
	w.ResponseWriter.WriteHeader(code)
}

func (w *statusWriter) Write(b []byte) (int, error) {
	if !w.wroteHeader {
		w.wroteHeader = true
	}
	return w.ResponseWriter.Write(b)
}
