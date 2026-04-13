package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/coreweave/my-app/middleware"
)

func main() {
	// --- Config from environment (never hardcode) ---
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	// --- Structured logging ---
	// SECURITY LESSON: JSON structured logging makes logs parseable by Splunk,
	// Datadog, and other log aggregators. This is critical for incident response —
	// you need to query and filter logs, not grep through plaintext.
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	// --- Startup security validation ---
	// SECURITY LESSON: Catch dangerous misconfigurations at boot, not in production.
	if os.Getenv("DEV_MODE") == "true" {
		slog.Warn("DEV_MODE is enabled — authentication is bypassed with a fake user. DO NOT deploy with DEV_MODE=true.")
	}
	if os.Getenv("DEV_MODE") != "true" && os.Getenv("OKTA_ISSUER") == "" {
		slog.Warn("OKTA_ISSUER is not set and DEV_MODE is off — auth will reject ALL requests. Set OKTA_ISSUER or DEV_MODE=true.")
	}
	if corsOrigins := os.Getenv("CORS_ORIGINS"); corsOrigins == "*" {
		slog.Warn("CORS_ORIGINS is wildcard '*' — ANY website can call your API. Set specific origins.")
	}

	// --- Routes ---
	mux := http.NewServeMux()

	// Health check — unauthenticated, required for k8s probes.
	// SECURITY LESSON: Health endpoints MUST be unauthenticated because k8s
	// liveness/readiness probes don't carry tokens. But they should return
	// minimal information — never expose version, config, or internal state.
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})

	// /api/me — returns the authenticated user's claims.
	// SECURITY LESSON: This endpoint lets the frontend discover who is logged
	// in and what groups they belong to, without exposing the raw JWT. The
	// claims are extracted server-side from the verified token, so the client
	// can't tamper with them.
	mux.Handle("GET /api/me", middleware.RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := middleware.UserFromContext(r.Context())
		if user == nil {
			http.Error(w, `{"error":"no user in context"}`, http.StatusUnauthorized)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"sub":    user.Subject,
			"email":  user.Email,
			"name":   user.Name,
			"groups": user.Groups,
		})
	})))

	// /api/hello — authenticated endpoint, returns a greeting.
	mux.Handle("GET /api/hello", middleware.RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := middleware.UserFromContext(r.Context())
		reqID := middleware.RequestIDFromContext(r.Context())

		slog.Info("hello endpoint",
			"request_id", reqID,
			"user", user.Email,
		)

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]string{
			"message":    "hello from secure template",
			"user":       user.Email,
			"request_id": reqID,
		})
	})))

	// --- Middleware chain ---
	// SECURITY LESSON: Middleware order matters. Request ID runs first so every
	// subsequent log line includes it. Security headers run early so they're set
	// even if a later handler errors. Rate limiting runs before auth to protect
	// the auth layer itself from being overwhelmed. Request size runs before
	// auth because auth doesn't need to read the body, but we want to reject
	// huge payloads before any processing.
	var handler http.Handler = mux
	handler = middleware.RequestSizeMiddleware(handler) // innermost — limits body reads
	handler = middleware.SecurityHeaders(handler)       // set headers on all responses
	handler = middleware.RateLimit(handler)              // protect against abuse
	handler = middleware.RequestID(handler)              // outermost — assigns trace ID

	// --- Server with secure defaults ---
	// SECURITY LESSON: Timeouts prevent slowloris attacks where an attacker
	// sends data very slowly to hold connections open and exhaust server resources.
	// ReadTimeout caps how long the server waits for the request.
	// WriteTimeout caps how long the server takes to write the response.
	// IdleTimeout caps how long keep-alive connections stay open.
	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      handler,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// --- Graceful shutdown ---
	// SECURITY LESSON: Graceful shutdown prevents data corruption and dropped
	// requests. In Kubernetes, the pod receives SIGTERM before being killed.
	// We stop accepting new connections and wait for in-flight requests to
	// finish (up to the shutdown timeout). Without this, active requests get
	// killed mid-response, which can corrupt data or leave transactions open.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	// Start server in a goroutine
	errCh := make(chan error, 1)
	go func() {
		slog.Info("server starting", "port", port)
		errCh <- srv.ListenAndServe()
	}()

	// Wait for shutdown signal or server error
	select {
	case <-ctx.Done():
		slog.Info("shutdown signal received, draining connections...")

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer cancel()

		if err := srv.Shutdown(shutdownCtx); err != nil {
			slog.Error("graceful shutdown failed", "error", err)
			os.Exit(1)
		}

		slog.Info("server stopped gracefully")

	case err := <-errCh:
		if err != nil && err != http.ErrServerClosed {
			slog.Error("server failed", "error", err)
			os.Exit(1)
		}
	}
}
