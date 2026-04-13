# =============================================================================
# Python Secure Dockerfile — CW Internal Template
# Multi-stage build: slim build image → slim runtime with venv only
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
# SECURITY LESSON: python:3.12-slim is the minimal official image — no gcc,
# no X11, no man pages. Slim cuts ~500MB of attack surface vs full python:3.12.
# For CW production, use the Chainguard Python image from the internal catalog.
FROM python:3.12-slim AS builder

LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Python microservice with isolated virtualenv"

WORKDIR /build

# SECURITY LESSON: Creating a virtualenv isolates deps from system Python.
# In runtime, we copy ONLY this venv — no pip, no setuptools, no build tools.
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# SECURITY LESSON: Copy pyproject.toml first for layer caching.
# Dependencies change less often than source code.
COPY pyproject.toml .

# SECURITY LESSON: --no-cache-dir prevents pip from storing downloaded packages.
# Install production deps only (no [dev] extras).
RUN pip install --no-cache-dir . 2>/dev/null || \
    (echo "pyproject.toml install failed, trying with source..." && \
     COPY . . && pip install --no-cache-dir .)

# Copy application source AFTER installing deps for cache efficiency.
COPY . .
RUN pip install --no-cache-dir .

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
# SECURITY LESSON: Fresh slim image — none of the build layers carry over.
FROM python:3.12-slim

LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Python microservice with isolated virtualenv"

# Install curl for healthcheck, clean up in same layer.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# SECURITY LESSON: Dedicated non-root user, no home dir, no shell.
RUN useradd --no-create-home --shell /usr/sbin/nologin appuser

# Copy virtualenv from build stage — the ONLY Python packages in the image.
COPY --from=builder /opt/venv /opt/venv

# Copy application code.
WORKDIR /app
COPY --from=builder /build/src/ /app/src/

ENV PATH="/opt/venv/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080

# SECURITY LESSON: Healthcheck verifies the app is responsive, not just alive.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

USER appuser

# SECURITY LESSON: Exec form — no shell injection, SIGTERM goes to Python.
ENTRYPOINT ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
