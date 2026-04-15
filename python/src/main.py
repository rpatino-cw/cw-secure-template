"""CW Secure Framework — FastAPI Application.

Entry point. Wires middleware, routes, templates, and security.
Keep this file thin — routes go in routes/, logic in services/.
"""

import os
import signal
import sys
from pathlib import Path

import structlog
from fastapi import Request
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from .middleware import (
    RateLimitMiddleware,
    RequestIDMiddleware,
    RequestSizeLimitMiddleware,
)
from .routes import api, health, pages

# --- Structured logging ---
structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.add_log_level,
        structlog.processors.JSONRenderer(),
    ],
)
logger = structlog.get_logger()

# --- App ---
_enable_docs = os.environ.get("ENABLE_DOCS", "true").lower() == "true"
_dev_mode = os.environ.get("DEV_MODE", "false").lower() == "true"

app = FastAPI(
    title="CW Secure App",
    docs_url="/docs" if _enable_docs else None,
    redoc_url=None,
)

# --- Templates + Static ---
_src_dir = Path(__file__).resolve().parent
app.mount("/static", StaticFiles(directory=_src_dir / "static"), name="static")
app.state.templates = Jinja2Templates(directory=_src_dir / "templates")

# --- Startup validation ---
_cors_origins = [o.strip() for o in os.environ.get("CORS_ORIGINS", "").split(",") if o.strip()]
_okta_issuer = os.environ.get("OKTA_ISSUER", "")

if not _dev_mode and not _okta_issuer:
    logger.warning("OKTA_ISSUER not set and DEV_MODE off — auth rejects all requests")
if _dev_mode:
    logger.warning("DEV_MODE enabled — auth bypassed with fake user. Do NOT deploy like this.")

# --- Middleware (reverse order: last added = first to run) ---
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
app.add_middleware(RateLimitMiddleware)
app.add_middleware(RequestSizeLimitMiddleware)
app.add_middleware(RequestIDMiddleware)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    # Allow inline styles + fonts for the dashboard
    response.headers["Content-Security-Policy"] = (
        "default-src 'self'; style-src 'self' https://fonts.googleapis.com 'unsafe-inline'; "
        "font-src 'self' https://fonts.gstatic.com"
    )
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


# --- Error handler ---
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error("unhandled exception", error=str(exc), path=request.url.path)
    return JSONResponse(status_code=500, content={"error": "Internal server error"})


# --- Graceful shutdown ---
def _handle_sigterm(signum, frame):
    logger.info("received SIGTERM, shutting down gracefully")
    sys.exit(0)


signal.signal(signal.SIGTERM, _handle_sigterm)

# --- Routes ---
app.include_router(health.router)
app.include_router(pages.router)
app.include_router(api.router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
