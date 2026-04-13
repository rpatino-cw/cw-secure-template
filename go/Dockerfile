# =============================================================================
# Go Secure Dockerfile — CW Internal Template
# Multi-stage build: CW Chainguard build image → minimal static runtime
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
# SECURITY LESSON: CW Chainguard images are distroless — no shell, no package
# manager, no CVEs from unused OS packages. cgr.dev/coreweave/go is our
# internally-vetted Go build image, pinned and scanned by AppSec.
FROM cgr.dev/coreweave/go:1.23 AS builder

LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Go microservice built with CW Chainguard base images"

# SECURITY LESSON: Setting a fixed WORKDIR avoids relying on image defaults.
WORKDIR /build

# SECURITY LESSON: Copy go.mod first and download deps separately.
# This layer caches dependencies so code changes don't re-download everything.
# No go.sum needed when using only stdlib (zero external deps).
COPY go.mod ./
RUN go mod download

# SECURITY LESSON: Copy source AFTER deps so the build cache stays warm.
COPY . .

# SECURITY LESSON: CGO_ENABLED=0 produces a fully static binary with no libc
# dependency. This means the runtime image needs ZERO shared libraries.
# -trimpath removes local filesystem paths from the binary.
# -ldflags="-s -w" strips debug symbols — smaller binary, less attack surface.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /build/server .

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
# SECURITY LESSON: chainguard/static is the smallest possible runtime — no shell,
# no package manager, no libc. Attack surface is effectively zero.
FROM cgr.dev/chainguard/static:latest

LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Go microservice built with CW Chainguard base images"

# SECURITY LESSON: Copy ONLY the compiled binary — no source, no tools, no .git.
COPY --from=builder /build/server /server

# SECURITY LESSON: Expose 8080 (unprivileged) instead of 80/443.
EXPOSE 8080

# SECURITY LESSON: Run as nobody (65534:65534). No user identity, no home dir,
# no shell, no write access. Combined with readOnlyRootFilesystem in K8s.
USER 65534:65534

# SECURITY LESSON: ENTRYPOINT with exec form (JSON array) — no shell involved.
# Signals (SIGTERM) go directly to the process for clean shutdown.
ENTRYPOINT ["/server"]
