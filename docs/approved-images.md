# Approved Container Images

Container image policy for CoreWeave internal applications. Use Chainguard images — not public Docker Hub images.

---

## The Rule

Every Dockerfile in a CW repo must use CoreWeave-approved Chainguard base images. Public Docker Hub images (`golang:1.25`, `python:3.12`, `node:20`, `ubuntu:24.04`) are not approved for production use. They carry unnecessary packages, unpatched CVEs, and no supply-chain attestation.

Chainguard images are minimal, distroless, and continuously patched. They are the default at CW.

---

## Approved Base Images

### Go

```dockerfile
# Build stage
FROM cgr.dev/coreweave/go:1.25 AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /app/server ./cmd/server

# Runtime stage — static binary, no OS needed
FROM cgr.dev/chainguard/static:latest
COPY --from=builder /app/server /server
ENTRYPOINT ["/server"]
```

| Stage | Image | Notes |
|-------|-------|-------|
| Build | `cgr.dev/coreweave/go:1.25` | Full Go toolchain for compilation |
| Runtime | `cgr.dev/chainguard/static:latest` | ~2MB, no shell, no OS packages — ideal for static Go binaries |

### Python

Python images are pulled through the Google Artifact Registry mirror maintained by the security team:

```dockerfile
FROM us-central1-docker.pkg.dev/coreweave-registry/chainguard-pull-through/coreweave/python:3.12
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "-m", "app"]
```

| Stage | Image | Notes |
|-------|-------|-------|
| Runtime | `us-central1-docker.pkg.dev/.../coreweave/python:3.12` | Pull-through mirror of Chainguard Python |

The mirror path is long but intentional — it routes through CW's Artifact Registry for caching and vulnerability scanning.

### Other Languages

If you need a base image for a language not listed here (Node.js, Rust, Java, etc.), check if a Chainguard variant exists:

1. Search the Chainguard catalog: `cgr.dev/chainguard/[language]`
2. Check if CW has a pull-through mirror by asking in **#security-team**
3. If neither exists, file a request (see below)

---

## If an Image Is Missing

If the Chainguard image you need is not available through the CW mirror:

1. Post in **#security-team** on Slack.
2. Include: the image you need (e.g., `chainguard/ruby:3.3`), why you need it, and which repo will use it.
3. The security team will evaluate and either provision a pull-through mirror or suggest an alternative.

Do not pull directly from `cgr.dev/chainguard/` in production without clearance — the CW mirrors exist to ensure images pass through the internal vulnerability scanner.

---

## Tag Policy

### Development

Use version tags for readability:

```dockerfile
FROM cgr.dev/coreweave/go:1.25
```

### Production

Pin to a specific digest. Tags are mutable — `1.25` today may point to a different image tomorrow. Digests are immutable:

```dockerfile
FROM cgr.dev/coreweave/go@sha256:a1b2c3d4e5f6...
```

To get the current digest:

```bash
crane digest cgr.dev/coreweave/go:1.25
```

Update digests when:
- Dependabot or Renovate flags a newer version
- A CVE is published against the current base image
- Monthly, as part of routine maintenance

### What NOT to do

```dockerfile
# BAD — mutable tag in production
FROM cgr.dev/coreweave/go:latest

# BAD — public Docker Hub image
FROM golang:1.25-alpine

# BAD — Ubuntu/Debian base with hundreds of unnecessary packages
FROM ubuntu:24.04
```

---

## Refresh Cadence

| Trigger | Action |
|---------|--------|
| Monthly | Check for newer Chainguard image versions, update digests |
| Dependabot/Renovate alert | Update the flagged image immediately |
| CVE published against base image | Update within 48 hours (critical) or 1 week (high) |
| New language/runtime needed | Request via #security-team before using |

---

## Image Scanning

Built images should be scanned for vulnerabilities before deployment. Recommended scanners:

- **Trivy** — `trivy image your-image:tag`
- **Grype** — `grype your-image:tag`

This template's CI pipeline does not yet include automated image scanning (planned addition). In the meantime, run scans locally before pushing:

```bash
# Scan your built image
docker build -t my-app:local .
trivy image my-app:local

# Fail on critical or high vulnerabilities
trivy image --exit-code 1 --severity CRITICAL,HIGH my-app:local
```

If scanning reveals vulnerabilities in the base image itself (not your code), update to the latest digest. If the vulnerability persists in the latest Chainguard image, report it in **#security-team**.

---

## Quick Reference

| Language | Build image | Runtime image |
|----------|-------------|---------------|
| Go | `cgr.dev/coreweave/go:1.25` | `cgr.dev/chainguard/static:latest` |
| Python | `us-central1-docker.pkg.dev/.../coreweave/python:3.12` | Same (interpreted, no separate build stage) |
| Other | Ask in #security-team | Depends on language |

When in doubt: smaller is better, fewer packages is safer, and pinned digests prevent surprises.
