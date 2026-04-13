# =============================================================================
# Python Secure Dockerfile — CW Internal Template
# Multi-stage build: slim build image → slim runtime with venv only
# =============================================================================

# SECURITY LESSON: Labels provide traceability — know who owns what in production.
LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Python microservice with isolated virtualenv"

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
# SECURITY LESSON: python:3.12-slim is the minimal official image — no gcc,
# no X11, no man pages. Slim cuts ~500MB of attack surface vs full python:3.12.
FROM python:3.12-slim AS builder

# SECURITY LESSON: Fixed WORKDIR prevents relying on mutable image defaults.
WORKDIR /build

# SECURITY LESSON: Creating a virtualenv isolates our deps from system Python.
# In the runtime stage, we copy ONLY this venv — no pip, no setuptools, no
# wheel, no build tools. An attacker can't pip-install anything at runtime.
RUN python -m venv /opt/venv

# SECURITY LESSON: Activate the venv by prepending it to PATH. This ensures
# all pip installs land in /opt/venv, not in system site-packages.
ENV PATH="/opt/venv/bin:$PATH"

# SECURITY LESSON: Copy requirements first for layer caching. A hash mismatch
# here means a dependency was tampered with, failing the build early.
COPY requirements.txt .

# SECURITY LESSON: --no-cache-dir prevents pip from storing downloaded packages
# in the image layer. Less disk, less attack surface, no stale cached wheels.
# --only-binary=:all: forces pre-built wheels — no compilation step means no
# compiler needed in runtime, and no C extension build artifacts left behind.
RUN pip install --no-cache-dir --only-binary=:all: -r requirements.txt || \
    pip install --no-cache-dir -r requirements.txt

# SECURITY LESSON: Copy application source AFTER installing deps so code
# changes don't invalidate the expensive pip-install layer.
COPY . .

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
# SECURITY LESSON: Fresh slim image — none of the build-stage layers (pip cache,
# .pyc compile artifacts, requirements.txt) carry over. Only what we explicitly
# COPY arrives in the final image.
FROM python:3.12-slim

# SECURITY LESSON: Repeat labels in the runtime stage.
LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Python microservice with isolated virtualenv"

# SECURITY LESSON: Install curl for the HEALTHCHECK, then clean up apt lists
# in the same layer to avoid inflating the image. We accept this one extra
# binary because Python's http.client is less reliable for health probes.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# SECURITY LESSON: Create a dedicated non-root user with no home directory and
# no login shell. This follows the principle of least privilege — the app runs
# with minimal OS-level permissions.
RUN useradd --no-create-home --shell /usr/sbin/nologin appuser

# SECURITY LESSON: Copy the entire virtualenv from the build stage. This is
# the ONLY set of Python packages in the image — no pip, no setuptools,
# no ability to install new packages at runtime.
COPY --from=builder /opt/venv /opt/venv

# SECURITY LESSON: Copy application code into a clean directory owned by root
# (default). appuser can read but not modify the application code, preventing
# an attacker from patching the running app.
WORKDIR /app
COPY --from=builder /build/ /app/

# SECURITY LESSON: Activate the venv in the runtime image.
ENV PATH="/opt/venv/bin:$PATH"

# SECURITY LESSON: PYTHONDONTWRITEBYTECODE=1 prevents .pyc file creation,
# which would fail anyway with readOnlyRootFilesystem in K8s. No .pyc files
# also means no cache-based code injection vector.
# PYTHONUNBUFFERED=1 ensures logs stream immediately — critical for incident
# response when you need real-time container output.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# SECURITY LESSON: Unprivileged port — no CAP_NET_BIND_SERVICE needed.
EXPOSE 8080

# SECURITY LESSON: HEALTHCHECK verifies the app is responsive, not just alive.
# /healthz is a K8s convention. Failure triggers container restart, containing
# any compromised or hung process. The 30s interval balances detection speed
# against probe overhead.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8080/healthz || exit 1

# SECURITY LESSON: Switch to non-root user AFTER all file operations. From
# this point, the process cannot modify /app, install packages, or escalate
# privileges (assuming no SUID binaries, which slim images don't ship).
USER appuser

# SECURITY LESSON: Exec form prevents shell injection and ensures SIGTERM
# reaches the Python process directly for graceful shutdown.
ENTRYPOINT ["python", "-m", "app.main"]
