"""Entry point — wires config, middleware, routes. Under 50 lines."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
import structlog
from src.config.settings import settings
from src.middleware.auth import AuthMiddleware
from src.middleware.ratelimit import RateLimitMiddleware
from src.middleware.requestid import RequestIdMiddleware
from src.routes import health

structlog.configure(processors=[structlog.processors.TimeStamper(fmt="iso"), structlog.processors.JSONRenderer()])
log = structlog.get_logger()


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("starting", env=settings.env, version="0.1.0")
    # validate required env at startup — fail fast
    settings.require_production_secrets()
    yield
    log.info("stopping")


app = FastAPI(docs_url=None, redoc_url=None, lifespan=lifespan)

app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.ALLOWED_HOSTS)
app.add_middleware(CORSMiddleware, allow_origins=settings.CORS_ORIGINS, allow_methods=["GET", "POST", "PUT", "DELETE"], allow_headers=["Authorization", "Content-Type"])
app.add_middleware(RequestIdMiddleware)
app.add_middleware(RateLimitMiddleware, requests_per_minute=settings.RATE_LIMIT)
app.add_middleware(AuthMiddleware)

app.include_router(health.router)

