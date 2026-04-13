"""Secure FastAPI application template for CoreWeave internal tools.

# SECURITY LESSON: This is the application entry point. Every security decision made here
# (middleware order, auth wiring, header defaults) sets the baseline for the entire app.
# Middleware executes in reverse order of registration — last added = first to run.
"""

import os
import signal
import sys

import structlog
from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict

from .middleware import (
    RateLimitMiddleware,
    RequestIDMiddleware,
    RequestSizeLimitMiddleware,
    get_current_user,
)

# --- Structured logging with contextvars for request ID propagation ---
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer(),
    ],
)
logger = structlog.get_logger()

# --- Docs: disabled by default, require explicit ENABLE_DOCS=true ---
# SECURITY LESSON: API docs (Swagger UI) expose your entire API surface to attackers.
# Never enable in production unless intentionally. Require an explicit opt-in.
_enable_docs = os.environ.get("ENABLE_DOCS", "false").lower() == "true"

app = FastAPI(
    title="My App",
    docs_url="/docs" if _enable_docs else None,
    redoc_url="/redoc" if _enable_docs else None,
)

# --- CORS: fix empty-string origin issue ---
# SECURITY LESSON: "".split(",") returns [""], which CORS middleware treats as allowing
# the origin "". Always filter empty strings to get an actually-empty list.
_raw_cors = os.environ.get("CORS_ORIGINS", "")
_cors_origins = [o.strip() for o in _raw_cors.split(",") if o.strip()]

# --- Startup security validation ---
# SECURITY LESSON: Catch dangerous misconfigurations at boot, not in production.
# These warnings fire once at startup so you see them immediately in logs.
if "*" in _cors_origins:
    logger.warning(
        "CORS_ORIGINS contains wildcard '*' — ANY website can call your API. "
        "Set CORS_ORIGINS to specific origins like 'https://myapp.internal.coreweave.com'"
    )
if os.environ.get("ALLOWED_HOSTS", "") == "*":
    logger.warning(
        "ALLOWED_HOSTS is wildcard '*' — disables trusted host protection. "
        "Set to specific hostnames."
    )
_dev_mode = os.environ.get("DEV_MODE", "false").lower() == "true"
_okta_issuer = os.environ.get("OKTA_ISSUER", "")
if not _dev_mode and not _okta_issuer:
    logger.warning(
        "OKTA_ISSUER is not set and DEV_MODE is off — auth will reject ALL requests. "
        "Set OKTA_ISSUER or enable DEV_MODE=true for local development."
    )
if _dev_mode:
    logger.warning(
        "DEV_MODE is enabled — authentication is bypassed with a fake user. "
        "DO NOT deploy with DEV_MODE=true."
    )

# --- Security middleware stack ---
# SECURITY LESSON: Middleware order matters. Starlette processes middleware in reverse
# registration order (last added runs first on the request). We want:
#   Request → RequestID → RequestSize → RateLimit → TrustedHost → CORS → SecurityHeaders → App
# So we register in reverse: CORS first (innermost), then outward.

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=os.environ.get("ALLOWED_HOSTS", "localhost,127.0.0.1").split(","),
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization"],
)

# SECURITY LESSON: Rate limiting before auth — we want to throttle attackers before
# they can even attempt authentication. This protects the auth layer itself.
app.add_middleware(RateLimitMiddleware)

# SECURITY LESSON: Request size check early — reject oversized payloads before wasting
# CPU on parsing, auth validation, or business logic.
app.add_middleware(RequestSizeLimitMiddleware)

# SECURITY LESSON: Request ID first (outermost) — every log line from every middleware
# and handler gets a correlation ID, making incident response possible.
app.add_middleware(RequestIDMiddleware)


# --- Security headers on every response ---
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    # SECURITY LESSON: These headers defend against common browser-based attacks:
    # - nosniff: prevents MIME-type sniffing (XSS via content-type confusion)
    # - DENY: prevents clickjacking via iframes
    # - CSP: restricts resource loading origins (XSS mitigation)
    # - HSTS: forces HTTPS for all future requests (prevents downgrade attacks)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Content-Security-Policy"] = "default-src 'self'"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


# --- Global error handler (never leak internals) ---
# SECURITY LESSON: Unhandled exceptions can leak stack traces, file paths, and database
# details. This catch-all ensures users only see "Internal server error" while the
# full error is logged server-side for debugging.
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("unhandled exception", error=str(exc), path=request.url.path)
    return JSONResponse(status_code=500, content={"error": "Internal server error"})


# --- Graceful shutdown ---
# SECURITY LESSON: Kubernetes sends SIGTERM before killing pods. If we don't handle it
# gracefully, in-flight requests get dropped and connections leak. Uvicorn handles
# SIGTERM natively, but we add explicit handling for direct execution.
def _handle_sigterm(signum, frame):
    logger.info("received SIGTERM, shutting down gracefully")
    sys.exit(0)


signal.signal(signal.SIGTERM, _handle_sigterm)


# --- Health check (unauthenticated, for k8s probes) ---
# SECURITY LESSON: Health checks MUST be unauthenticated. Kubernetes liveness/readiness
# probes don't carry auth tokens. If /healthz requires auth, k8s will restart your pod
# every 30 seconds thinking it's dead.
@app.get("/healthz")
async def healthz():
    return {"status": "ok"}


# --- /api/me — returns the authenticated user's claims ---
# SECURITY LESSON: This endpoint lets the frontend (or a developer) inspect what the
# server sees after JWT validation. Useful for debugging RBAC issues without
# exposing raw tokens in logs.
@app.get("/api/me")
async def get_me(user: dict = Depends(get_current_user)):
    return {
        "sub": user.get("sub"),
        "email": user.get("email"),
        "name": user.get("name"),
        "groups": user.get("groups", []),
    }


# --- Example: validated input with Pydantic strict mode ---
# SECURITY LESSON: Pydantic strict mode rejects type coercion (e.g., int "12345" won't
# silently become string "12345"). This prevents entire classes of injection where
# attackers send unexpected types hoping for implicit conversion.
class ItemCreate(BaseModel):
    model_config = ConfigDict(strict=True)

    name: str
    description: str = ""


# SECURITY LESSON: Depends(get_current_user) on this route means unauthenticated requests
# get a 401 before reaching any business logic. The dependency runs before the handler.
@app.post("/api/items")
async def create_item(item: ItemCreate, user: dict = Depends(get_current_user)):
    logger.info("item created", name=item.name, user_id=user.get("sub"))
    return {"name": item.name, "description": item.description, "created_by": user.get("sub")}


if __name__ == "__main__":
    import uvicorn

    # SECURITY LESSON: Bind to 0.0.0.0 inside containers so the service is reachable.
    # In production, Traefik/ingress handles TLS termination and access control.
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
