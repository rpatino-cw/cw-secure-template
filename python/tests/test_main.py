"""Tests for the secure FastAPI template.

DEV_MODE=true is set so auth middleware returns a fake test user,
allowing tests to pass without a real Okta instance.
ALLOWED_HOSTS includes 'testserver' so TrustedHostMiddleware accepts test requests.
"""

import os

# SECURITY LESSON: Set env vars before importing the app so all modules pick them up
# at load time. In CI, you'd use a real test Okta tenant instead of DEV_MODE.
os.environ["DEV_MODE"] = "true"
os.environ["ALLOWED_HOSTS"] = "localhost,127.0.0.1,testserver"

from fastapi.testclient import TestClient

from src.main import app

client = TestClient(app)


def test_healthz():
    """Health check must return 200 without auth — k8s probes depend on this."""
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_security_headers():
    """Every response must include security headers, even unauthenticated routes."""
    response = client.get("/healthz")
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"
    assert response.headers["Content-Security-Policy"] == "default-src 'self'"
    assert "Strict-Transport-Security" in response.headers


def test_request_id_generated():
    """Responses must include an X-Request-ID header."""
    response = client.get("/healthz")
    assert "X-Request-ID" in response.headers
    # UUID4 format: 8-4-4-4-12
    request_id = response.headers["X-Request-ID"]
    assert len(request_id) == 36
    assert request_id.count("-") == 4


def test_request_id_propagated():
    """If the client sends X-Request-ID, the server must echo it back."""
    custom_id = "test-trace-id-12345"
    response = client.get("/healthz", headers={"X-Request-ID": custom_id})
    assert response.headers["X-Request-ID"] == custom_id


def test_get_me():
    """GET /api/me returns the dev user claims when DEV_MODE=true."""
    response = client.get("/api/me")
    assert response.status_code == 200
    data = response.json()
    assert data["sub"] == "dev-user-001"
    assert data["email"] == "dev@localhost"
    assert "groups" in data
    assert "developers" in data["groups"]


def test_create_item_valid():
    """POST /api/items with valid data returns the item plus created_by."""
    response = client.post("/api/items", json={"name": "test-item"})
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "test-item"
    assert data["created_by"] == "dev-user-001"


def test_create_item_missing_name():
    """POST /api/items without required 'name' field returns 422."""
    response = client.post("/api/items", json={})
    assert response.status_code == 422  # Pydantic validation


def test_create_item_wrong_type():
    """POST /api/items with wrong type for 'name' returns 422 in strict mode.

    Pydantic strict mode rejects int-to-str coercion, unlike the default lenient mode.
    This is intentional — strict mode prevents type confusion attacks.
    """
    response = client.post("/api/items", json={"name": 12345})
    assert response.status_code == 422


def test_request_size_limit():
    """Requests with Content-Length exceeding the limit get 413."""
    response = client.post(
        "/api/items",
        json={"name": "test"},
        headers={"Content-Length": "2000000"},
    )
    assert response.status_code == 413


def test_cors_no_wildcard():
    """CORS should not allow wildcard origin."""
    response = client.options(
        "/api/items",
        headers={
            "Origin": "https://evil.example.com",
            "Access-Control-Request-Method": "POST",
        },
    )
    # Without CORS_ORIGINS set, no origins are allowed — the header should be absent
    assert "access-control-allow-origin" not in response.headers
