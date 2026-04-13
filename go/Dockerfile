# =============================================================================
# Go Secure Dockerfile — CW Internal Template
# Multi-stage build: CW Chainguard build image → minimal static runtime
# =============================================================================

# SECURITY LESSON: Labels provide traceability — know who owns what in production.
LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Go microservice built with CW Chainguard base images"

# ---------------------------------------------------------------------------
# Stage 1: Build
# ---------------------------------------------------------------------------
# SECURITY LESSON: CW Chainguard images are distroless — no shell, no package
# manager, no CVEs from unused OS packages. cgr.dev/coreweave/go is our
# internally-vetted Go build image, pinned and scanned by AppSec.
FROM cgr.dev/coreweave/go:1.25 AS builder

# SECURITY LESSON: Setting a fixed WORKDIR avoids relying on image defaults
# which can change between versions.
WORKDIR /build

# SECURITY LESSON: Copy go.mod/go.sum first and download deps separately.
# This layer caches dependencies so code changes don't re-download everything,
# AND it means a tampered dependency would break the checksum here, not silently
# slip into the final binary.
COPY go.mod go.sum ./
RUN go mod download && go mod verify

# SECURITY LESSON: Copy source AFTER deps so the build cache stays warm.
COPY . .

# SECURITY LESSON: CGO_ENABLED=0 produces a fully static binary with no libc
# dependency. This means the runtime image needs ZERO shared libraries,
# eliminating an entire class of supply-chain attacks (malicious .so injection).
# -trimpath removes local filesystem paths from the binary, preventing info leaks.
# -ldflags="-s -w" strips debug symbols and DWARF info — smaller binary, less
# reverse-engineering surface.
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -trimpath -ldflags="-s -w" -o /build/server ./cmd/server

# ---------------------------------------------------------------------------
# Stage 2: Runtime
# ---------------------------------------------------------------------------
# SECURITY LESSON: chainguard/static is the smallest possible runtime — no shell,
# no package manager, no libc, no busybox. Attack surface is effectively zero.
# An attacker who gets code execution has nothing to pivot with.
FROM cgr.dev/chainguard/static:latest

# SECURITY LESSON: Repeat labels in the runtime stage — only the final stage's
# labels end up in the shipped image.
LABEL maintainer="your-team@coreweave.com"
LABEL description="Secure Go microservice built with CW Chainguard base images"

# SECURITY LESSON: Copy ONLY the compiled binary — no source code, no build
# tools, no test files, no .git directory. The runtime image contains exactly
# one file plus the CA certificates baked into chainguard/static.
COPY --from=builder /build/server /server

# SECURITY LESSON: Expose declares intent — it doesn't actually open the port.
# This is documentation for reviewers and orchestrators. Use 8080 (unprivileged)
# instead of 80/443 so the process never needs CAP_NET_BIND_SERVICE.
EXPOSE 8080

# SECURITY LESSON: Run as nobody:nobody (65534:65534). Even if an attacker
# achieves code execution, they have no user identity, no home directory, no
# shell, and no write access to the filesystem. Combined with readOnlyRootFilesystem
# in K8s, this makes persistence nearly impossible.
USER 65534:65534

# SECURITY LESSON: HEALTHCHECK lets Docker (and by extension K8s liveness probes)
# verify the process is actually serving, not just running. We use the binary
# itself via wget since chainguard/static includes wget but no curl/shell.
# Failure triggers a restart, limiting the blast radius of a hung process.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ["/server", "--healthcheck"]

# SECURITY LESSON: ENTRYPOINT with exec form (JSON array) — no shell involved.
# This means no shell injection is possible, and signals (SIGTERM) go directly
# to the process for clean shutdown.
ENTRYPOINT ["/server"]
