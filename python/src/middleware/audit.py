"""Audit logging middleware — structured JSON logs for every request.

Records user_id, action (HTTP method), resource (path), timestamp, and request_id
for compliance and incident response. Logs are emitted as structured JSON via structlog.
"""

import time
from datetime import datetime, timezone

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

logger = structlog.get_logger("audit")


class AuditMiddleware(BaseHTTPMiddleware):
    """Logs an audit trail entry for every request with user context when available."""

    async def dispatch(self, request: Request, call_next):
        start_time = time.monotonic()

        response = await call_next(request)

        duration_ms = round((time.monotonic() - start_time) * 1000, 2)

        # Extract user_id from request state (set by auth middleware).
        # Falls back to "anonymous" for unauthenticated endpoints like /healthz.
        user_id = "anonymous"
        if hasattr(request.state, "user") and request.state.user:
            user_id = request.state.user.get("sub", "anonymous")

        # Extract request_id from request state (set by RequestIDMiddleware).
        request_id = getattr(request.state, "request_id", "unknown")

        # Client IP for audit trail — use forwarded header if behind a proxy.
        client_ip = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        if not client_ip:
            client_ip = request.client.host if request.client else "unknown"

        logger.info(
            "audit",
            user_id=user_id,
            action=request.method,
            resource=request.url.path,
            query=str(request.query_params) if request.query_params else None,
            status_code=response.status_code,
            duration_ms=duration_ms,
            client_ip=client_ip,
            request_id=request_id,
            timestamp=datetime.now(timezone.utc).isoformat(),
            user_agent=request.headers.get("User-Agent", ""),
        )

        return response
