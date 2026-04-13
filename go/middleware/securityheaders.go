package middleware

import (
	"net/http"
)

// SECURITY LESSON: Security headers — These HTTP response headers instruct
// browsers to enable built-in security features. Without them, browsers use
// permissive defaults that leave users vulnerable to XSS, clickjacking,
// MIME-sniffing, and protocol downgrade attacks. These headers are cheap
// (zero runtime cost) and protect every response automatically.

// SecurityHeaders sets required security headers on every response.
//
// Headers set:
//   - X-Content-Type-Options: nosniff — prevents browsers from MIME-sniffing
//     the response body to determine the content type, which could let an
//     attacker trick the browser into executing a file as JavaScript.
//   - X-Frame-Options: DENY — prevents the page from being embedded in an
//     iframe, which blocks clickjacking attacks where an attacker overlays
//     an invisible iframe to steal clicks.
//   - Content-Security-Policy: default-src 'self' — restricts which resources
//     the page can load to same-origin only. This is the strongest CSP default
//     and blocks inline scripts, eval, and third-party resources.
//   - Strict-Transport-Security: max-age=31536000; includeSubDomains — tells
//     browsers to ONLY connect via HTTPS for the next year. Even if the user
//     types http://, the browser upgrades to HTTPS automatically.
//   - Cache-Control: no-store — prevents caching of authenticated responses.
//     Without this, sensitive data could be stored in browser or proxy caches.
func SecurityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Content-Security-Policy", "default-src 'self'")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		w.Header().Set("Cache-Control", "no-store")
		next.ServeHTTP(w, r)
	})
}
