"""Sliding-window rate limiter with per-user support as Starlette middleware.

# SECURITY LESSON: Rate limiting — without it, a single client can exhaust your server's
# resources (CPU, memory, DB connections) by flooding it with requests. This is the simplest
# defense against brute-force attacks and application-layer DoS.
#
# Per-user rate limiting means authenticated users get their own quota, preventing one
# user from consuming another user's budget. Unauthenticated requests fall back to per-IP.
"""

import asyncio
import os
import time
from collections import defaultdict

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

logger = structlog.get_logger()

# --- Configuration from environment ---
RATE_LIMIT_RPS = int(os.environ.get("RATE_LIMIT_RPS", "10"))
RATE_LIMIT_BURST = int(os.environ.get("RATE_LIMIT_BURST", "20"))
CLEANUP_INTERVAL_SECONDS = 300  # 5 minutes


def _get_rate_limit_key(request: Request) -> str:
    """Determine the rate limit key: user_id if authenticated, IP otherwise.

    # SECURITY LESSON: Per-user rate limiting is fairer and more precise. Without it,
    # all users behind a corporate NAT (same IP) share one bucket, and a single
    # abusive user can lock out an entire office. Per-user limits isolate quotas.
    # We fall back to IP for unauthenticated endpoints (e.g., login, healthz).
    """
    # Check if auth middleware has set user info on the request state.
    if hasattr(request.state, "user") and request.state.user:
        user_id = request.state.user.get("sub", "")
        if user_id:
            return f"user:{user_id}"

    # Fallback to per-IP when no authenticated user is available.
    # SECURITY LESSON: Use X-Forwarded-For when behind a reverse proxy (Traefik, nginx).
    # But ONLY trust it if your proxy is configured to set it — otherwise attackers
    # can spoof it. Here we fall back to the direct client IP.
    client_ip = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
    if not client_ip:
        client_ip = request.client.host if request.client else "unknown"
    return f"ip:{client_ip}"


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Sliding-window rate limiter tracking per-user (or per-IP) request timestamps.

    # SECURITY LESSON: In-memory rate limiting works for single-instance deployments.
    # For multi-instance (k8s), use Redis or a sidecar like Envoy/Istio rate limiting.
    # This implementation is a starting point — swap the storage backend for production scale.
    """

    def __init__(self, app, rps: int = RATE_LIMIT_RPS, burst: int = RATE_LIMIT_BURST):
        super().__init__(app)
        self.burst = burst
        # SECURITY LESSON: window_seconds = burst / rps. At 10 rps with burst 20,
        # the window is 2 seconds — allowing 20 requests per 2-second window.
        self.window_seconds = burst / rps if rps > 0 else 1.0
        # SECURITY LESSON: defaultdict(list) — each key gets a list of request timestamps.
        # The sliding window checks how many timestamps fall within the last N seconds.
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._cleanup_task: asyncio.Task | None = None

    async def dispatch(self, request: Request, call_next):
        # Start background cleanup on first request
        if self._cleanup_task is None:
            self._cleanup_task = asyncio.create_task(self._periodic_cleanup())

        key = _get_rate_limit_key(request)

        now = time.monotonic()
        timestamps = self._requests[key]

        # Purge timestamps outside the sliding window
        cutoff = now - self.window_seconds
        self._requests[key] = [ts for ts in timestamps if ts > cutoff]
        timestamps = self._requests[key]

        if len(timestamps) >= self.burst:
            retry_after = self.window_seconds - (now - timestamps[0]) if timestamps else 1.0
            retry_after = max(retry_after, 0.1)
            logger.warning(
                "rate limit exceeded",
                rate_limit_key=key,
                path=request.url.path,
                request_count=len(timestamps),
                limit=self.burst,
            )
            # SECURITY LESSON: Retry-After header tells well-behaved clients when to retry.
            # Without it, clients often retry immediately, making the overload worse.
            return JSONResponse(
                status_code=429,
                content={"error": "Too many requests"},
                headers={"Retry-After": str(int(retry_after) + 1)},
            )

        self._requests[key].append(now)
        return await call_next(request)

    async def _periodic_cleanup(self):
        """Background task to prune stale entries from the tracking dict.

        # SECURITY LESSON: Without cleanup, the in-memory dict grows unbounded as new
        # keys arrive. An attacker rotating source IPs could cause memory exhaustion.
        # Periodic cleanup bounds memory usage.
        """
        while True:
            await asyncio.sleep(CLEANUP_INTERVAL_SECONDS)
            now = time.monotonic()
            cutoff = now - self.window_seconds
            stale_keys = [
                k for k, timestamps in self._requests.items()
                if not timestamps or timestamps[-1] <= cutoff
            ]
            for k in stale_keys:
                del self._requests[k]
            if stale_keys:
                logger.debug("rate limiter cleanup", removed_keys=len(stale_keys))
