"""Rate limit — in-memory token bucket per IP. Replace with Redis in prod."""
import time
from collections import defaultdict
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, requests_per_minute: int = 100):
        super().__init__(app)
        self.rpm = requests_per_minute
        self.buckets: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request, call_next):
        ip = request.client.host if request.client else "unknown"
        now = time.time()
        self.buckets[ip] = [t for t in self.buckets[ip] if now - t < 60]
        if len(self.buckets[ip]) >= self.rpm:
            return JSONResponse({"error": "rate limit exceeded"}, status_code=429, headers={"Retry-After": "60"})
        self.buckets[ip].append(now)
        return await call_next(request)
