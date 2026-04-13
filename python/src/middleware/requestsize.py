"""Request body size limit middleware.

# SECURITY LESSON: Without a body size limit, an attacker can send a multi-gigabyte request
# body to exhaust your server's memory. This is a trivial denial-of-service attack that
# costs the attacker almost nothing. Always cap request body size.
"""

import os

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

logger = structlog.get_logger()

# Default: 1 MB
MAX_REQUEST_BODY_BYTES = int(os.environ.get("MAX_REQUEST_BODY_BYTES", "1048576"))


class RequestSizeLimitMiddleware(BaseHTTPMiddleware):
    """Reject requests whose Content-Length exceeds the configured maximum."""

    def __init__(self, app, max_bytes: int = MAX_REQUEST_BODY_BYTES):
        super().__init__(app)
        self.max_bytes = max_bytes

    async def dispatch(self, request: Request, call_next):
        # SECURITY LESSON: Check Content-Length header before reading the body.
        # This rejects oversized requests early, before the server wastes memory buffering them.
        # Note: this doesn't protect against chunked transfer-encoding without Content-Length.
        # For full protection, also configure uvicorn's --limit-request-body or use a
        # reverse proxy (Traefik/nginx) with client_max_body_size.
        content_length = request.headers.get("content-length")

        if content_length is not None:
            try:
                length = int(content_length)
            except ValueError:
                # SECURITY LESSON: Malformed Content-Length headers can confuse proxies
                # and cause request smuggling. Reject them outright.
                return JSONResponse(
                    status_code=400,
                    content={"error": "Invalid Content-Length header"},
                )

            if length > self.max_bytes:
                logger.warning(
                    "request body too large",
                    content_length=length,
                    max_bytes=self.max_bytes,
                    path=request.url.path,
                    client=request.client.host if request.client else "unknown",
                )
                return JSONResponse(
                    status_code=413,
                    content={"error": "Request body too large"},
                    headers={
                        # SECURITY LESSON: Tell the client what the limit is so they can
                        # adjust. This is a courtesy, not a security requirement.
                        "X-Max-Content-Length": str(self.max_bytes),
                    },
                )

        return await call_next(request)
