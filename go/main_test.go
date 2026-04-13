package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/coreweave/my-app/middleware"
)

func TestHealthz(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if w.Body.String() != "ok" {
		t.Errorf("expected 'ok', got '%s'", w.Body.String())
	}
}

func TestSecurityHeaders(t *testing.T) {
	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	handler := middleware.SecurityHeaders(inner)

	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	expected := map[string]string{
		"X-Content-Type-Options":    "nosniff",
		"X-Frame-Options":          "DENY",
		"Content-Security-Policy":  "default-src 'self'",
		"Strict-Transport-Security": "max-age=31536000; includeSubDomains",
		"Cache-Control":            "no-store",
	}

	for header, value := range expected {
		if got := w.Header().Get(header); got != value {
			t.Errorf("header %s: expected '%s', got '%s'", header, value, got)
		}
	}
}

func TestHealthzWithMiddlewareStack(t *testing.T) {
	// Healthz should work through the full middleware stack (no auth required).
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// Wire the same middleware chain as main.go
	var handler http.Handler = mux
	handler = middleware.RequestSizeMiddleware(handler)
	handler = middleware.SecurityHeaders(handler)
	// Skip RateLimit in tests to avoid goroutine leaks from the cleanup ticker
	handler = middleware.RequestID(handler)

	req := httptest.NewRequest("GET", "/healthz", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if w.Body.String() != "ok" {
		t.Errorf("expected 'ok', got '%s'", w.Body.String())
	}

	// Should have a request ID assigned
	if rid := w.Header().Get("X-Request-ID"); rid == "" {
		t.Error("expected X-Request-ID header on response")
	}

	// Should have security headers
	if ct := w.Header().Get("X-Content-Type-Options"); ct != "nosniff" {
		t.Errorf("expected nosniff, got %q", ct)
	}
}

func TestRequestIDPropagation(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /test", func(w http.ResponseWriter, r *http.Request) {
		// Read the request ID from context
		rid := middleware.RequestIDFromContext(r.Context())
		w.Write([]byte(rid))
	})

	handler := middleware.RequestID(mux)

	// Send a request with a pre-existing request ID
	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("X-Request-ID", "upstream-trace-abc")
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}

	// Response header should propagate the upstream ID
	if rid := w.Header().Get("X-Request-ID"); rid != "upstream-trace-abc" {
		t.Errorf("expected propagated request ID, got %q", rid)
	}

	// Body (from context) should match
	if body := w.Body.String(); body != "upstream-trace-abc" {
		t.Errorf("expected request ID in context, got %q", body)
	}
}

func TestApiMeRequiresAuth(t *testing.T) {
	// /api/me without a token should return 401.
	// We test the handler directly with RequireAuth wrapping.
	handler := middleware.RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := middleware.UserFromContext(r.Context())
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"sub":   user.Subject,
			"email": user.Email,
		})
	}))

	// Set OKTA_ISSUER so the handler doesn't return 500 for misconfiguration
	t.Setenv("OKTA_ISSUER", "https://example.okta.com")
	t.Setenv("DEV_MODE", "false")

	req := httptest.NewRequest("GET", "/api/me", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for unauthenticated /api/me, got %d", w.Code)
	}
}

func TestApiMeWithDevMode(t *testing.T) {
	// In DEV_MODE, /api/me should return the fake dev user.
	t.Setenv("DEV_MODE", "true")

	handler := middleware.RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := middleware.UserFromContext(r.Context())
		if user == nil {
			http.Error(w, "no user", http.StatusUnauthorized)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"sub":   user.Subject,
			"email": user.Email,
			"name":  user.Name,
		})
	}))

	req := httptest.NewRequest("GET", "/api/me", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200 in DEV_MODE, got %d: %s", w.Code, w.Body.String())
	}

	var body map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatalf("unmarshal response: %v", err)
	}
	if email, ok := body["email"].(string); !ok || email != "dev@localhost" {
		t.Errorf("expected dev@localhost email, got %v", body["email"])
	}
}
