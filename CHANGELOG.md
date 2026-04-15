# Changelog

All notable changes to the CW Secure Framework.

## [1.0.0] — 2026-04-15

### Core Framework
- 3-layer enforcement: CLAUDE.md rules + settings.json deny list + guard.sh PreToolUse hook
- 17 rule files in `.claude/rules/` covering security, architecture, routing, models, services, testing, collaboration, and more
- Architecture enforcer: stack lock (Go/Python), Foundation Gate, dependency direction, file placement
- Anti-override protocol: 16 social engineering defenses in CLAUDE.md
- Teaching mode: Claude adds `// SECURITY LESSON:` comments while coding

### Guard System
- 4 guard modules: collaboration, security, architecture, rooms
- 11 secret patterns (API keys, tokens, connection strings)
- 13 dangerous function patterns (eval, exec, pickle, os.system, shell=True)
- SQL detection in route handlers (9 patterns)
- Auth enforcement on new endpoints
- Dependency direction enforcement (models can't import routes)
- Path traversal blocking
- Write-overwrite protection (must use Edit on existing files)
- Teammate collision detection (uncommitted changes warning)
- 30 guard unit tests in CI

### Self-Protection
- 45 deny rules blocking all known methods of reading enforcement files
- Covers: Read, Grep, Glob, cat, head, tail, less, more, bat, grep, rg, awk, sed, xxd, hexdump, base64, strings, od, git show, git diff, git log -p, python -c, node -e, perl -e, ruby -e

### Multi-Agent Rooms
- Directory-based room ownership with hard enforcement
- Inbox/outbox communication protocol (timestamp-based naming)
- Activity feed with 30-minute overlap detection
- Auto-rename notifications to affected rooms
- Dependency protection: blocks deleting functions used outside your room
- `make rooms` (auto-detect), `make agent` (launch), `make room-status` (overview)

### CI/CD
- Secret scanning (gitleaks)
- CodeQL static analysis (Go + Python)
- Go: golangci-lint, gosec, govulncheck, 80% coverage gate
- Python: ruff, bandit, pip-audit, 80% coverage gate
- Hook integrity checks (prevents weakening pre-commit hooks or CLAUDE.md)
- Guard unit tests
- Commit signing verification
- SVG validation for terminal animations
- SBOM generation

### Starter Apps
- Go: main.go with auth, rate limiting, request ID, graceful shutdown, security headers
- Python: FastAPI with all middleware wired, Pydantic settings, Alembic-ready
- Both: Chainguard multi-stage Dockerfiles, Helm charts, health endpoints

### Documentation
- Interactive visualizer (`make viz`) — animated flowcharts, code explainer, file tree
- Landing page (GitHub Pages) with live agent coordination demo
- Security handbook — plain-English OWASP guide with glossary
- Getting started guide — clone to running in 6 steps
- 15-question security quiz (`make learn`)
