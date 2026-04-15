"""Health check routes — unauthenticated, for k8s probes."""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def healthz():
    """Kubernetes liveness/readiness probe. Must stay unauthenticated."""
    return {"status": "ok"}
