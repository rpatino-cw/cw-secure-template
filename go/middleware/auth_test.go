package middleware

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"math/big"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

// -------------------------------------------------------------------
// Test helpers — build JWTs for testing without an actual IdP
// -------------------------------------------------------------------

// testKeyPair holds an RSA key pair and its JWK representation for testing.
type testKeyPair struct {
	Private *rsa.PrivateKey
	Public  *rsa.PublicKey
	Kid     string
}

func generateTestKeyPair(t *testing.T) *testKeyPair {
	t.Helper()
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	if err != nil {
		t.Fatalf("generate RSA key: %v", err)
	}
	return &testKeyPair{
		Private: key,
		Public:  &key.PublicKey,
		Kid:     "test-key-1",
	}
}

// signJWT creates a signed RS256 JWT for testing.
func signJWT(t *testing.T, kp *testKeyPair, header map[string]string, payload map[string]any) string {
	t.Helper()

	headerJSON, err := json.Marshal(header)
	if err != nil {
		t.Fatalf("marshal header: %v", err)
	}
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}

	headerB64 := base64.RawURLEncoding.EncodeToString(headerJSON)
	payloadB64 := base64.RawURLEncoding.EncodeToString(payloadJSON)

	signedData := []byte(headerB64 + "." + payloadB64)
	h := sha256.Sum256(signedData)

	sig, err := rsa.SignPKCS1v15(rand.Reader, kp.Private, cryptoSHA256, h[:])
	if err != nil {
		t.Fatalf("sign JWT: %v", err)
	}

	sigB64 := base64.RawURLEncoding.EncodeToString(sig)
	return headerB64 + "." + payloadB64 + "." + sigB64
}

// makeValidToken creates a token with standard valid claims.
func makeValidToken(t *testing.T, kp *testKeyPair, issuer, audience string) string {
	t.Helper()
	header := map[string]string{
		"alg": "RS256",
		"kid": kp.Kid,
		"typ": "JWT",
	}
	payload := map[string]any{
		"sub":    "user-123",
		"email":  "test@coreweave.com",
		"name":   "Test User",
		"groups": []string{"engineering", "admin"},
		"iss":    issuer,
		"aud":    audience,
		"exp":    time.Now().Add(1 * time.Hour).Unix(),
		"iat":    time.Now().Unix(),
	}
	return signJWT(t, kp, header, payload)
}

// startTestJWKSServer starts a mock OIDC discovery + JWKS server.
func startTestJWKSServer(t *testing.T, kp *testKeyPair) *httptest.Server {
	t.Helper()

	nB64 := base64.RawURLEncoding.EncodeToString(kp.Public.N.Bytes())
	eBytes := big.NewInt(int64(kp.Public.E)).Bytes()
	eB64 := base64.RawURLEncoding.EncodeToString(eBytes)

	mux := http.NewServeMux()

	// JWKS endpoint
	mux.HandleFunc("/keys", func(w http.ResponseWriter, r *http.Request) {
		jwks := map[string]any{
			"keys": []map[string]any{
				{
					"kty": "RSA",
					"kid": kp.Kid,
					"use": "sig",
					"alg": "RS256",
					"n":   nB64,
					"e":   eB64,
				},
			},
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(jwks)
	})

	srv := httptest.NewServer(mux)

	// OpenID Configuration endpoint
	mux.HandleFunc("/.well-known/openid-configuration", func(w http.ResponseWriter, r *http.Request) {
		config := map[string]string{
			"jwks_uri": srv.URL + "/keys",
			"issuer":   srv.URL,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(config)
	})

	return srv
}

// resetGlobalJWKS clears the cached JWKS between tests.
func resetGlobalJWKS() {
	globalJWKS.mu.Lock()
	defer globalJWKS.mu.Unlock()
	globalJWKS.keys = make(map[string]*rsa.PublicKey)
	globalJWKS.fetched = time.Time{}
}

// dummyHandler returns 200 with the user's email from context.
func dummyHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		user := UserFromContext(r.Context())
		if user != nil {
			w.Write([]byte(user.Email))
		} else {
			w.Write([]byte("no user"))
		}
	})
}

// -------------------------------------------------------------------
// Tests
// -------------------------------------------------------------------

func TestRequireAuth_ValidToken(t *testing.T) {
	resetGlobalJWKS()
	kp := generateTestKeyPair(t)
	srv := startTestJWKSServer(t, kp)
	defer srv.Close()

	os.Setenv("OKTA_ISSUER", srv.URL)
	os.Setenv("OKTA_AUDIENCE", "test-audience")
	os.Setenv("DEV_MODE", "false")
	defer func() {
		os.Unsetenv("OKTA_ISSUER")
		os.Unsetenv("OKTA_AUDIENCE")
		os.Unsetenv("DEV_MODE")
	}()

	token := makeValidToken(t, kp, srv.URL, "test-audience")

	handler := RequireAuth(dummyHandler())
	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d: %s", w.Code, w.Body.String())
	}
	if body := w.Body.String(); body != "test@coreweave.com" {
		t.Errorf("expected user email in body, got %q", body)
	}
}

func TestRequireAuth_ExpiredToken(t *testing.T) {
	resetGlobalJWKS()
	kp := generateTestKeyPair(t)
	srv := startTestJWKSServer(t, kp)
	defer srv.Close()

	os.Setenv("OKTA_ISSUER", srv.URL)
	os.Setenv("OKTA_AUDIENCE", "test-audience")
	os.Setenv("DEV_MODE", "false")
	defer func() {
		os.Unsetenv("OKTA_ISSUER")
		os.Unsetenv("OKTA_AUDIENCE")
		os.Unsetenv("DEV_MODE")
	}()

	header := map[string]string{"alg": "RS256", "kid": kp.Kid, "typ": "JWT"}
	payload := map[string]any{
		"sub":    "user-123",
		"email":  "expired@coreweave.com",
		"name":   "Expired User",
		"groups": []string{},
		"iss":    srv.URL,
		"aud":    "test-audience",
		"exp":    time.Now().Add(-1 * time.Hour).Unix(), // expired 1 hour ago
		"iat":    time.Now().Add(-2 * time.Hour).Unix(),
	}
	token := signJWT(t, kp, header, payload)

	handler := RequireAuth(dummyHandler())
	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for expired token, got %d", w.Code)
	}
}

func TestRequireAuth_WrongAudience(t *testing.T) {
	resetGlobalJWKS()
	kp := generateTestKeyPair(t)
	srv := startTestJWKSServer(t, kp)
	defer srv.Close()

	os.Setenv("OKTA_ISSUER", srv.URL)
	os.Setenv("OKTA_AUDIENCE", "correct-audience")
	os.Setenv("DEV_MODE", "false")
	defer func() {
		os.Unsetenv("OKTA_ISSUER")
		os.Unsetenv("OKTA_AUDIENCE")
		os.Unsetenv("DEV_MODE")
	}()

	// Token has wrong audience
	token := makeValidToken(t, kp, srv.URL, "wrong-audience")

	handler := RequireAuth(dummyHandler())
	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for wrong audience, got %d", w.Code)
	}
}

func TestRequireAuth_MissingAuthorizationHeader(t *testing.T) {
	os.Setenv("OKTA_ISSUER", "https://example.okta.com")
	os.Setenv("DEV_MODE", "false")
	defer func() {
		os.Unsetenv("OKTA_ISSUER")
		os.Unsetenv("DEV_MODE")
	}()

	handler := RequireAuth(dummyHandler())
	req := httptest.NewRequest("GET", "/api/test", nil)
	// No Authorization header set
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for missing auth header, got %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "missing Authorization header") {
		t.Errorf("expected descriptive error, got %q", w.Body.String())
	}
}

func TestRequireAuth_InvalidBearerScheme(t *testing.T) {
	os.Setenv("OKTA_ISSUER", "https://example.okta.com")
	os.Setenv("DEV_MODE", "false")
	defer func() {
		os.Unsetenv("OKTA_ISSUER")
		os.Unsetenv("DEV_MODE")
	}()

	handler := RequireAuth(dummyHandler())
	req := httptest.NewRequest("GET", "/api/test", nil)
	req.Header.Set("Authorization", "Basic dXNlcjpwYXNz") // Basic auth, not Bearer
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for non-Bearer scheme, got %d", w.Code)
	}
}

func TestRequireGroup_UserInGroup(t *testing.T) {
	user := &UserClaims{
		Subject: "user-123",
		Email:   "admin@coreweave.com",
		Groups:  []string{"engineering", "admin"},
	}

	handler := RequireGroup("admin", dummyHandler())
	req := httptest.NewRequest("GET", "/admin/settings", nil)
	ctx := ContextWithUser(req.Context(), user)
	req = req.WithContext(ctx)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200 for user in group, got %d", w.Code)
	}
}

func TestRequireGroup_UserNotInGroup(t *testing.T) {
	user := &UserClaims{
		Subject: "user-456",
		Email:   "viewer@coreweave.com",
		Groups:  []string{"viewers"},
	}

	handler := RequireGroup("admin", dummyHandler())
	req := httptest.NewRequest("GET", "/admin/settings", nil)
	ctx := ContextWithUser(req.Context(), user)
	req = req.WithContext(ctx)
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusForbidden {
		t.Errorf("expected 403 for user not in group, got %d", w.Code)
	}
}

func TestRequireGroup_NoUser(t *testing.T) {
	handler := RequireGroup("admin", dummyHandler())
	req := httptest.NewRequest("GET", "/admin/settings", nil)
	// No user in context
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("expected 401 for no user, got %d", w.Code)
	}
}

func TestRequireAuth_DevModeBypass(t *testing.T) {
	os.Setenv("DEV_MODE", "true")
	defer os.Unsetenv("DEV_MODE")

	handler := RequireAuth(dummyHandler())
	req := httptest.NewRequest("GET", "/api/test", nil)
	// No Authorization header — DEV_MODE should bypass
	w := httptest.NewRecorder()

	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200 in DEV_MODE, got %d", w.Code)
	}
	if body := w.Body.String(); body != "dev@localhost" {
		t.Errorf("expected dev user email, got %q", body)
	}
}

func TestVerifyJWT_MalformedToken(t *testing.T) {
	_, err := verifyJWT("not.a.valid.jwt.with.too.many.parts", "https://issuer", "aud")
	if err == nil {
		t.Error("expected error for malformed token")
	}
	if !strings.Contains(err.Error(), "malformed JWT") {
		t.Errorf("expected 'malformed JWT' error, got %q", err.Error())
	}
}

func TestVerifyJWT_UnsupportedAlgorithm(t *testing.T) {
	header := map[string]string{"alg": "HS256", "kid": "test", "typ": "JWT"}
	headerJSON, _ := json.Marshal(header)
	payload := map[string]any{"sub": "test"}
	payloadJSON, _ := json.Marshal(payload)

	token := fmt.Sprintf("%s.%s.fakesig",
		base64.RawURLEncoding.EncodeToString(headerJSON),
		base64.RawURLEncoding.EncodeToString(payloadJSON),
	)

	_, err := verifyJWT(token, "https://issuer", "aud")
	if err == nil {
		t.Error("expected error for unsupported algorithm")
	}
	if !strings.Contains(err.Error(), "unsupported JWT algorithm") {
		t.Errorf("expected algorithm error, got %q", err.Error())
	}
}

func TestUserFromContext_Nil(t *testing.T) {
	req := httptest.NewRequest("GET", "/", nil)
	user := UserFromContext(req.Context())
	if user != nil {
		t.Error("expected nil user from empty context")
	}
}

func TestContextWithUser_RoundTrip(t *testing.T) {
	original := &UserClaims{
		Subject: "sub-1",
		Email:   "roundtrip@test.com",
		Name:    "Round Trip",
		Groups:  []string{"group-a"},
	}

	req := httptest.NewRequest("GET", "/", nil)
	ctx := ContextWithUser(req.Context(), original)
	got := UserFromContext(ctx)

	if got == nil {
		t.Fatal("expected user from context, got nil")
	}
	if got.Subject != original.Subject {
		t.Errorf("subject: got %q, want %q", got.Subject, original.Subject)
	}
	if got.Email != original.Email {
		t.Errorf("email: got %q, want %q", got.Email, original.Email)
	}
}
