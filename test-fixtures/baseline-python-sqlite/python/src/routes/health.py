"""Health check — unauthenticated."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/healthz")
def health() -> dict:
    return {"status": "ok"}
