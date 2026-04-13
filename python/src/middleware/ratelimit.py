"""Sliding-window per-IP rate limiter as Starlette middleware.

# SECURITY LESSON: Rate limiting — without it, a single client can exhaust your server's
# resources (CPU, memory, DB connections) by flooding it with requests. This is the simplest
# defense against brute-force attacks and application-layer DoS.
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


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Sliding-window rate limiter tracking per-IP request timestamps.

    # SECURITY LESSON: In-memory rate limiting works for single-instance deployments.
    # For multi-instance (k8s), use Redis or a sidecar like Envoy/Istio rate limiting.
    # This implementation is a starting point — swap the storage backend for production scale.
    """

    def __init__(self, app, rps: int = RATE_LIMIT_RPS, burst: int = RATE_LIMIT_BURST):
        super().__init__(app)
        self.rps = rps
        self.burst = burst
        self.window_seconds = 1.0
        # SECURITY LESSON: defaultdict(list) — each IP gets a list of request timestamps.
        # The sliding window checks how many timestamps fall within the last N seconds.
        self._requests: dict[str, list[float]] = defaultdict(list)
        self._cleanup_task: asyncio.Task | None = None

    async def dispatch(self, request: Request, call_next):
        # Start background cleanup on first request
        if self._cleanup_task is None:
            self._cleanup_task = asyncio.create_task(self._periodic_cleanup())

        # SECURITY LESSON: Use X-Forwarded-For when behind a reverse proxy (Traefik, nginx).
        # But ONLY trust it if your proxy is configured to set it — otherwise attackers
        # can spoof it. Here we fall back to the direct client IP.
        client_ip = request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
        if not client_ip:
            client_ip = request.client.host if request.client else "unknown"

        now = time.monotonic()
        timestamps = self._requests[client_ip]

        # Purge timestamps outside the sliding window
        cutoff = now - self.window_seconds
        self._requests[client_ip] = [ts for ts in timestamps if ts > cutoff]
        timestamps = self._requests[client_ip]

        if len(timestamps) >= self.burst:
            retry_after = self.window_seconds - (now - timestamps[0]) if timestamps else 1.0
            retry_after = max(retry_after, 0.1)
            logger.warning(
                "rate limit exceeded",
                client_ip=client_ip,
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

        self._requests[client_ip].append(now)
        return await call_next(request)

    async def _periodic_cleanup(self):
        """Background task to prune stale IP entries from the tracking dict.

        # SECURITY LESSON: Without cleanup, the in-memory dict grows unbounded as new IPs
        # arrive. An attacker rotating source IPs could cause memory exhaustion.
        # Periodic cleanup bounds memory usage.
        """
        while True:
            await asyncio.sleep(CLEANUP_INTERVAL_SECONDS)
            now = time.monotonic()
            cutoff = now - self.window_seconds
            stale_ips = [
                ip for ip, timestamps in self._requests.items()
                if not timestamps or timestamps[-1] <= cutoff
            ]
            for ip in stale_ips:
                del self._requests[ip]
            if stale_ips:
                logger.debug("rate limiter cleanup", removed_ips=len(stale_ips))
