// Package middleware provides HTTP middleware for the secure template.
// This file implements Okta OIDC JWT verification using only stdlib + crypto.
package middleware

import (
	"context"
	"crypto/rsa"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"math/big"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"
)

// SECURITY LESSON: Context keys — We use a private type so no other package can
// collide with our context values. This prevents accidental or malicious key collisions.
type contextKey string

const (
	userContextKey contextKey = "user"
)

// UserClaims holds the identity extracted from a verified JWT.
// These are the standard OIDC claims plus the groups claim used for RBAC.
type UserClaims struct {
	Subject string   `json:"sub"`
	Email   string   `json:"email"`
	Name    string   `json:"name"`
	Groups  []string `json:"groups"`
}

// UserFromContext extracts the authenticated user from the request context.
// Returns nil if no user is present (unauthenticated request).
func UserFromContext(ctx context.Context) *UserClaims {
	u, _ := ctx.Value(userContextKey).(*UserClaims)
	return u
}

// ContextWithUser stores user claims in the context.
func ContextWithUser(ctx context.Context, u *UserClaims) context.Context {
	return context.WithValue(ctx, userContextKey, u)
}

// -------------------------------------------------------------------
// JWKS fetching and caching
// -------------------------------------------------------------------

// SECURITY LESSON: JWKS (JSON Web Key Set) — The identity provider (Okta) publishes
// its public keys at a well-known URL. We fetch and cache these keys to verify JWT
// signatures. Keys rotate periodically (key rotation), so we refresh the cache to
// pick up new keys and drop revoked ones. Without JWKS validation, anyone could
// forge a JWT with any claims they want.

// jwkSet holds cached JWKS keys fetched from the identity provider.
type jwkSet struct {
	mu      sync.RWMutex
	keys    map[string]*rsa.PublicKey // kid -> public key
	fetched time.Time
}

// jwk represents a single JSON Web Key in the JWKS response.
type jwk struct {
	Kty string `json:"kty"`
	Kid string `json:"kid"`
	Use string `json:"use"`
	N   string `json:"n"`
	E   string `json:"e"`
	Alg string `json:"alg"`
}

type jwksResponse struct {
	Keys []jwk `json:"keys"`
}

type oidcConfig struct {
	JWKSURI string `json:"jwks_uri"`
}

var (
	globalJWKS     = &jwkSet{keys: make(map[string]*rsa.PublicKey)}
	jwksRefreshTTL = 1 * time.Hour
)

// fetchJWKS retrieves the JWKS from the Okta OIDC discovery endpoint.
// It first fetches the OpenID configuration to discover the jwks_uri,
// then fetches and parses the actual key set.
func fetchJWKS(issuer string) (map[string]*rsa.PublicKey, error) {
	// SECURITY LESSON: OpenID Connect Discovery — The issuer publishes a
	// .well-known/openid-configuration document that tells us where to find
	// the JWKS, token endpoint, and other metadata. This is standardized in
	// RFC 8414 so we don't hardcode provider-specific URLs.
	discoveryURL := strings.TrimRight(issuer, "/") + "/.well-known/openid-configuration"

	client := &http.Client{Timeout: 10 * time.Second}

	resp, err := client.Get(discoveryURL)
	if err != nil {
		return nil, fmt.Errorf("fetch OIDC discovery: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("OIDC discovery returned %d", resp.StatusCode)
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20)) // 1MB limit
	if err != nil {
		return nil, fmt.Errorf("read OIDC discovery: %w", err)
	}

	var config oidcConfig
	if err := json.Unmarshal(body, &config); err != nil {
		return nil, fmt.Errorf("parse OIDC discovery: %w", err)
	}

	if config.JWKSURI == "" {
		return nil, fmt.Errorf("OIDC discovery missing jwks_uri")
	}

	// Fetch the actual JWKS
	jwksResp, err := client.Get(config.JWKSURI)
	if err != nil {
		return nil, fmt.Errorf("fetch JWKS: %w", err)
	}
	defer jwksResp.Body.Close()

	if jwksResp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("JWKS endpoint returned %d", jwksResp.StatusCode)
	}

	jwksBody, err := io.ReadAll(io.LimitReader(jwksResp.Body, 1<<20))
	if err != nil {
		return nil, fmt.Errorf("read JWKS: %w", err)
	}

	var jwks jwksResponse
	if err := json.Unmarshal(jwksBody, &jwks); err != nil {
		return nil, fmt.Errorf("parse JWKS: %w", err)
	}

	keys := make(map[string]*rsa.PublicKey)
	for _, k := range jwks.Keys {
		if k.Kty != "RSA" || k.Use != "sig" {
			continue
		}
		pub, err := parseRSAPublicKey(k)
		if err != nil {
			slog.Warn("skipping invalid JWKS key", "kid", k.Kid, "error", err)
			continue
		}
		keys[k.Kid] = pub
	}

	if len(keys) == 0 {
		return nil, fmt.Errorf("JWKS contained no usable RSA signing keys")
	}

	return keys, nil
}

// parseRSAPublicKey converts a JWK into an *rsa.PublicKey.
func parseRSAPublicKey(k jwk) (*rsa.PublicKey, error) {
	// SECURITY LESSON: JWK format — The modulus (n) and exponent (e) are
	// base64url-encoded big integers. We decode them and construct an RSA
	// public key. This is the same key the IdP used to sign the JWT.
	nBytes, err := base64.RawURLEncoding.DecodeString(k.N)
	if err != nil {
		return nil, fmt.Errorf("decode modulus: %w", err)
	}

	eBytes, err := base64.RawURLEncoding.DecodeString(k.E)
	if err != nil {
		return nil, fmt.Errorf("decode exponent: %w", err)
	}

	n := new(big.Int).SetBytes(nBytes)
	e := new(big.Int).SetBytes(eBytes)

	if !e.IsInt64() {
		return nil, fmt.Errorf("exponent too large")
	}

	return &rsa.PublicKey{
		N: n,
		E: int(e.Int64()),
	}, nil
}

// getOrRefreshJWKS returns cached keys or fetches fresh ones if the cache is stale.
func getOrRefreshJWKS(issuer string) (map[string]*rsa.PublicKey, error) {
	globalJWKS.mu.RLock()
	if time.Since(globalJWKS.fetched) < jwksRefreshTTL && len(globalJWKS.keys) > 0 {
		keys := globalJWKS.keys
		globalJWKS.mu.RUnlock()
		return keys, nil
	}
	globalJWKS.mu.RUnlock()

	globalJWKS.mu.Lock()
	defer globalJWKS.mu.Unlock()

	// Double-check after acquiring write lock (another goroutine may have refreshed).
	if time.Since(globalJWKS.fetched) < jwksRefreshTTL && len(globalJWKS.keys) > 0 {
		return globalJWKS.keys, nil
	}

	keys, err := fetchJWKS(issuer)
	if err != nil {
		// If we have stale keys, use them rather than failing hard.
		if len(globalJWKS.keys) > 0 {
			slog.Warn("JWKS refresh failed, using stale keys", "error", err)
			return globalJWKS.keys, nil
		}
		return nil, err
	}

	globalJWKS.keys = keys
	globalJWKS.fetched = time.Now()
	slog.Info("JWKS refreshed", "key_count", len(keys))
	return keys, nil
}

// -------------------------------------------------------------------
// JWT parsing and verification (manual, no external deps)
// -------------------------------------------------------------------

// SECURITY LESSON: JWT Structure — A JWT has three base64url-encoded parts
// separated by dots: HEADER.PAYLOAD.SIGNATURE. The header tells us the
// algorithm and key ID (kid). The payload contains claims (who, when, for whom).
// The signature proves the token was issued by someone holding the private key
// that matches the public key in the JWKS. We verify: (1) signature is valid,
// (2) token is not expired, (3) issuer matches our Okta tenant, (4) audience
// matches our app. Without ALL of these checks, an attacker could forge tokens.

type jwtHeader struct {
	Alg string `json:"alg"`
	Kid string `json:"kid"`
	Typ string `json:"typ"`
}

type jwtPayload struct {
	Sub    string   `json:"sub"`
	Email  string   `json:"email"`
	Name   string   `json:"name"`
	Groups []string `json:"groups"`
	Iss    string   `json:"iss"`
	Aud    jsonAud  `json:"aud"`
	Exp    int64    `json:"exp"`
	Iat    int64    `json:"iat"`
	Nbf    int64    `json:"nbf"`
}

// jsonAud handles the "aud" claim which can be a single string or an array.
type jsonAud []string

func (a *jsonAud) UnmarshalJSON(data []byte) error {
	// Try string first
	var single string
	if err := json.Unmarshal(data, &single); err == nil {
		*a = []string{single}
		return nil
	}
	// Try array
	var multi []string
	if err := json.Unmarshal(data, &multi); err != nil {
		return err
	}
	*a = multi
	return nil
}

// verifyJWT parses and verifies a raw JWT string against the JWKS.
// It checks signature, expiry, issuer, and audience.
func verifyJWT(tokenStr, issuer, audience string) (*UserClaims, error) {
	parts := strings.Split(tokenStr, ".")
	if len(parts) != 3 {
		return nil, fmt.Errorf("malformed JWT: expected 3 parts, got %d", len(parts))
	}

	// Decode header
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, fmt.Errorf("decode JWT header: %w", err)
	}

	var header jwtHeader
	if err := json.Unmarshal(headerBytes, &header); err != nil {
		return nil, fmt.Errorf("parse JWT header: %w", err)
	}

	// SECURITY LESSON: Algorithm validation — We only accept RS256. If we
	// accepted "none" or "HS256", an attacker could forge tokens trivially.
	// Always whitelist the algorithm you expect; never trust the header blindly.
	if header.Alg != "RS256" {
		return nil, fmt.Errorf("unsupported JWT algorithm: %s (only RS256 allowed)", header.Alg)
	}

	// Look up the signing key
	keys, err := getOrRefreshJWKS(issuer)
	if err != nil {
		return nil, fmt.Errorf("get JWKS: %w", err)
	}

	pubKey, ok := keys[header.Kid]
	if !ok {
		// Key not found — try a forced refresh in case keys rotated.
		// SECURITY LESSON: Key rotation — IdPs rotate signing keys periodically.
		// If we see an unknown kid, we refresh the JWKS once before rejecting.
		globalJWKS.mu.Lock()
		globalJWKS.fetched = time.Time{} // force refresh
		globalJWKS.mu.Unlock()

		keys, err = getOrRefreshJWKS(issuer)
		if err != nil {
			return nil, fmt.Errorf("JWKS refresh after unknown kid: %w", err)
		}
		pubKey, ok = keys[header.Kid]
		if !ok {
			return nil, fmt.Errorf("JWT kid %q not found in JWKS", header.Kid)
		}
	}

	// Verify signature: RS256 = RSASSA-PKCS1-v1_5 with SHA-256
	sigBytes, err := base64.RawURLEncoding.DecodeString(parts[2])
	if err != nil {
		return nil, fmt.Errorf("decode JWT signature: %w", err)
	}

	// The signed data is "header.payload" (the raw base64url parts, not decoded)
	signedData := []byte(parts[0] + "." + parts[1])
	if err := verifyRS256(pubKey, signedData, sigBytes); err != nil {
		return nil, fmt.Errorf("JWT signature verification failed: %w", err)
	}

	// Decode payload
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return nil, fmt.Errorf("decode JWT payload: %w", err)
	}

	var payload jwtPayload
	if err := json.Unmarshal(payloadBytes, &payload); err != nil {
		return nil, fmt.Errorf("parse JWT payload: %w", err)
	}

	// Validate time claims
	now := time.Now().Unix()

	// SECURITY LESSON: Expiry check — Without this, a stolen token works forever.
	// JWTs are bearer tokens: anyone who has the token IS the user. Expiry limits
	// the window an attacker has if they steal one.
	if payload.Exp > 0 && now > payload.Exp {
		return nil, fmt.Errorf("JWT expired at %d, current time %d", payload.Exp, now)
	}

	// nbf = "not before" — token isn't valid yet
	if payload.Nbf > 0 && now < payload.Nbf {
		return nil, fmt.Errorf("JWT not yet valid (nbf=%d, now=%d)", payload.Nbf, now)
	}

	// SECURITY LESSON: Issuer validation — Ensures this token came from OUR Okta
	// tenant, not some other IdP or a malicious server. Without this, an attacker
	// with their own Okta tenant could issue tokens your app would accept.
	expectedIssuer := strings.TrimRight(issuer, "/")
	actualIssuer := strings.TrimRight(payload.Iss, "/")
	if actualIssuer != expectedIssuer {
		return nil, fmt.Errorf("JWT issuer mismatch: got %q, want %q", payload.Iss, issuer)
	}

	// SECURITY LESSON: Audience validation — Ensures this token was issued FOR
	// this application. Without this, a token issued for app-A could be replayed
	// against app-B if they share the same IdP. The audience claim prevents this.
	if audience != "" {
		found := false
		for _, a := range payload.Aud {
			if a == audience {
				found = true
				break
			}
		}
		if !found {
			return nil, fmt.Errorf("JWT audience mismatch: got %v, want %q", []string(payload.Aud), audience)
		}
	}

	return &UserClaims{
		Subject: payload.Sub,
		Email:   payload.Email,
		Name:    payload.Name,
		Groups:  payload.Groups,
	}, nil
}

// verifyRS256 verifies an RS256 (RSASSA-PKCS1-v1_5 SHA-256) signature.
func verifyRS256(pub *rsa.PublicKey, signedData, signature []byte) error {
	// SECURITY LESSON: We use crypto/rsa.VerifyPKCS1v15 which is the standard
	// Go way to verify PKCS#1 v1.5 signatures. RS256 = RSA + SHA-256 + PKCS1v15.
	// We hash the signed data with SHA-256, then verify the signature against
	// the public key. If the signature doesn't match, the token was tampered with.
	h := sha256Hash(signedData)
	return rsa.VerifyPKCS1v15(pub, cryptoSHA256, h, signature)
}

// -------------------------------------------------------------------
// Auth middleware
// -------------------------------------------------------------------

// RequireAuth validates the JWT from the Authorization header.
// On success, it stores UserClaims in the request context.
// On failure, it returns 401 Unauthorized.
//
// SECURITY LESSON: Bearer tokens — The Authorization header format is
// "Bearer <token>". This is the standard way to pass JWTs in API requests.
// Unlike cookies, bearer tokens are NOT auto-sent by browsers, which means
// they're immune to CSRF attacks — but they must be stored securely on the
// client side (never in localStorage for web apps).
func RequireAuth(next http.Handler) http.Handler {
	issuer := os.Getenv("OKTA_ISSUER")
	audience := os.Getenv("OKTA_AUDIENCE")
	devMode := os.Getenv("DEV_MODE") == "true"

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// DEV_MODE bypass — injects a fake test user for local development.
		if devMode {
			// SECURITY LESSON: DEV_MODE bypass — This exists ONLY for local
			// development when you don't have Okta credentials. The loud warning
			// on every request makes it impossible to accidentally ship this to
			// production. If you see this warning in a deployed environment,
			// something is very wrong.
			slog.Warn("DEV_MODE: authentication bypassed -- DO NOT USE IN PRODUCTION",
				"path", r.URL.Path,
				"method", r.Method,
			)
			fakeUser := &UserClaims{
				Subject: "dev-user-001",
				Email:   "dev@localhost",
				Name:    "Dev User",
				Groups:  []string{"everyone", "admin"},
			}
			ctx := ContextWithUser(r.Context(), fakeUser)
			next.ServeHTTP(w, r.WithContext(ctx))
			return
		}

		if issuer == "" {
			slog.Error("OKTA_ISSUER not set — cannot verify JWTs")
			http.Error(w, `{"error":"server misconfigured"}`, http.StatusInternalServerError)
			return
		}

		authHeader := r.Header.Get("Authorization")
		if authHeader == "" {
			http.Error(w, `{"error":"missing Authorization header"}`, http.StatusUnauthorized)
			return
		}

		// SECURITY LESSON: We enforce the "Bearer " prefix. Some implementations
		// accept bare tokens, but that's ambiguous and error-prone.
		if !strings.HasPrefix(authHeader, "Bearer ") {
			http.Error(w, `{"error":"Authorization header must use Bearer scheme"}`, http.StatusUnauthorized)
			return
		}

		tokenStr := strings.TrimPrefix(authHeader, "Bearer ")
		if tokenStr == "" {
			http.Error(w, `{"error":"empty bearer token"}`, http.StatusUnauthorized)
			return
		}

		claims, err := verifyJWT(tokenStr, issuer, audience)
		if err != nil {
			slog.Warn("JWT verification failed",
				"error", err,
				"path", r.URL.Path,
			)
			http.Error(w, `{"error":"invalid or expired token"}`, http.StatusUnauthorized)
			return
		}

		slog.Info("authenticated request",
			"sub", claims.Subject,
			"email", claims.Email,
			"path", r.URL.Path,
		)

		ctx := ContextWithUser(r.Context(), claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// RequireGroup wraps a handler to enforce group membership.
// The user must already be authenticated (RequireAuth must run first).
// Returns 403 Forbidden if the user is not in the required group.
//
// SECURITY LESSON: RBAC (Role-Based Access Control) — Instead of checking
// individual permissions, we check group membership. Okta manages group
// assignments centrally, so adding/removing access is an IdP operation,
// not a code change. This is the principle of least privilege in action.
func RequireGroup(group string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := UserFromContext(r.Context())
		if user == nil {
			http.Error(w, `{"error":"authentication required"}`, http.StatusUnauthorized)
			return
		}

		for _, g := range user.Groups {
			if g == group {
				next.ServeHTTP(w, r)
				return
			}
		}

		slog.Warn("group access denied",
			"user", user.Subject,
			"required_group", group,
			"user_groups", user.Groups,
			"path", r.URL.Path,
		)
		http.Error(w, `{"error":"forbidden: insufficient group membership"}`, http.StatusForbidden)
	})
}
