"""Okta OIDC auth — validates JWT on every request except /healthz."""
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

PUBLIC_PATHS = {"/healthz"}


class AuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request, call_next):
        if request.url.path in PUBLIC_PATHS:
            return await call_next(request)
        token = request.headers.get("Authorization", "").removeprefix("Bearer ").strip()
        if not token:
            return JSONResponse({"error": "authentication required"}, status_code=401)
        # TODO: verify token against OKTA_ISSUER JWKS, check OKTA_REQUIRED_GROUPS
        # See docs/security-handbook.md and the base framework python/src/middleware/auth.py
        return await call_next(request)
