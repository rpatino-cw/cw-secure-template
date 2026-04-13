"""Request ID middleware — assigns a unique ID to every request for tracing.

# SECURITY LESSON: Request IDs are critical for incident response. When something goes wrong,
# you need to correlate logs across services. Without request IDs, debugging distributed
# systems is like finding a needle in a haystack — with no magnet.
"""

import uuid

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

logger = structlog.get_logger()

REQUEST_ID_HEADER = "X-Request-ID"


class RequestIDMiddleware(BaseHTTPMiddleware):
    """Generate or propagate a request ID, bind it to structlog context."""

    async def dispatch(self, request: Request, call_next):
        # SECURITY LESSON: Propagate incoming request IDs for distributed tracing.
        # If an upstream service already assigned an ID, reuse it so the entire
        # request chain shares one correlation ID.
        request_id = request.headers.get(REQUEST_ID_HEADER)

        if not request_id:
            # SECURITY LESSON: UUID4 is cryptographically random — unpredictable and
            # collision-resistant. Never use sequential IDs for request tracing;
            # they leak request volume information to attackers.
            request_id = str(uuid.uuid4())

        # Bind request_id to structlog so every log line in this request includes it.
        # SECURITY LESSON: structlog.contextvars binds per-async-context, so concurrent
        # requests don't bleed their IDs into each other's logs.
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        # Store on request.state so downstream code can access it
        request.state.request_id = request_id

        response = await call_next(request)
        response.headers[REQUEST_ID_HEADER] = request_id
        return response
