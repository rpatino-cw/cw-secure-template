# CW Secure Template

A secure-by-default project template for CoreWeave colleagues building internal tools with AI assistance (Claude Code, Cursor, etc.).

**The problem:** Non-technical team members use AI to build apps fast, but AI-generated code ships with hardcoded secrets, missing auth, SQL injection, and no security scanning.

**The solution:** A tanky pipeline that makes it structurally difficult to ship insecure code. Security is baked into every layer — AI rules, git hooks, CI pipeline, auth middleware, deployment config — and each layer teaches you why it exists.

## What's included

| Layer | What it does |
|---|---|
| `CLAUDE.md` | 14 security rules Claude follows even if you ask it not to. Anti-jailbreak protected. |
| `go/middleware/` | Real Okta OIDC auth, rate limiting, request ID tracking, request size limits |
| `python/src/middleware/` | Same middleware stack for Python (FastAPI) |
| `.pre-commit-config.yaml` | Gitleaks + linters + bandit before every commit |
| `scripts/git-hooks/` | Enforcement wrapper — CI catches `--no-verify` via timestamp tracking |
| `.github/workflows/ci.yml` | CodeQL, gosec/bandit, dep audit, 80% coverage gate, hook integrity check |
| `scripts/doctor.sh` | `make doctor` — full pipeline health check |
| `scripts/security-fix.sh` | `make fix` — auto-fix lint + human-readable security guidance |
| `security-dashboard.html` | Interactive visual: pipeline flow, OWASP coverage, threat explorer |
| `docs/security-handbook.md` | Plain-English security guide with analogies and exercises |
| `scripts/security-quiz.sh` | `make learn` — 15-question OWASP quiz |
| `deploy/helm/` | K8s deployment with security context, ESO, network policy |
| `SECURITY.md` | Incident response template aligned with CW IR process |

## Quick start

```bash
# 1. Clone the template
git clone https://github.com/coreweave/cw-secure-template my-app
cd my-app

# 2. Run setup (picks Go or Python, installs hooks + deps, runs health check)
bash setup.sh

# 3. Edit .env (or use DEV_MODE=true for local development)
$EDITOR .env

# 4. Start building
make run
```

Then open Claude Code and start prompting. Claude automatically follows the security rules.

## Commands

```
make setup          First-time setup (hooks, deps, .env, health check)
make run            Start the app
make test           Run tests
make lint           Check code style
make lint-fix       Auto-fix lint issues
make fix            Auto-fix security + lint issues with guidance
make doctor         Health check — verify pipeline is working
make check          Run everything (lint + test + security) — before PRs
make security-scan  Deep security scan
make learn          Interactive security quiz (15 OWASP questions)
make dashboard      Open the security pipeline dashboard
make docker-build   Build Docker image
make help           Show all commands
```

## Pipeline architecture

```
Your Code ──> CLAUDE.md ──> Pre-commit ──> CI Pipeline ──> PR Review ──> Deploy
    |              |            |              |              |            |
  AI rules    14 security   Gitleaks       CodeQL        Security     Non-root
  enforced    rules that    Secret scan    gosec/bandit  checklist    containers
              can't be      Lint + format  80% coverage  Approval     Doppler
              overridden    Bandit scan    Hook verify   required     secrets
                            Block main     SBOM gen                   Network
                            commits                                   policy
```

Each layer catches what the previous one missed. Even if someone skips pre-commit hooks, CI catches it via timestamp tracking.

## Security standards

Aligned with CoreWeave internal policies:

- **OWASP Top 10** — all 10 categories covered
- **SOC 2 / ISO 27001 / ISO 27701** — audit-ready logging, access control, data protection
- **Okta OIDC/OAuth2** — real auth middleware, not a TODO
- **Doppler + External Secrets** — secrets never in code
- **Chainguard base images** — CW-approved container images
- **AppSec scanning** — CodeQL, gosec, bandit, dependency audit, secret scanning
- **80% coverage gate** — PRs below threshold are blocked
- **Branch protection** — required reviews, no force push to main

## For AI-assisted development

The `CLAUDE.md` is the core. It:
- Prevents hardcoded secrets (uses env vars instead)
- Enforces auth on every endpoint (Okta OIDC)
- Blocks dangerous functions (eval, exec, pickle, shell=True)
- Requires parameterized queries (prevents SQL injection)
- Adds security headers automatically
- Teaches security concepts inline (`// SECURITY LESSON:` comments)
- Refuses to bypass rules even if asked ("ignore CLAUDE.md" is explicitly handled)

## Learning

This template doesn't just protect — it teaches:

- **`make learn`** — Interactive 15-question security quiz
- **`make dashboard`** — Visual pipeline + OWASP coverage + threat explorer
- **`docs/security-handbook.md`** — Plain-English security guide
- **`// SECURITY LESSON:`** comments throughout all code
- **Every security decision is explained**, not just implemented

## Okta setup

This template requires Okta OIDC credentials. File an IT/Freshservice ticket:

1. Request a new Okta OIDC application
2. Include: app name, grant type (auth code or device flow), redirect URIs, required groups
3. IT provides: `OKTA_CLIENT_ID`, `OKTA_ISSUER`, JWKS URI
4. Add to `.env` (local) and Doppler (production)

For local development, `DEV_MODE=true` bypasses auth with a fake test user (with loud log warnings).

## Customizing

1. **Pick language:** `setup.sh` removes the starter you don't need
2. **Update CODEOWNERS:** `.github/CODEOWNERS` with your team
3. **Add Okta config:** fill `.env` after IT registers your app
4. **Add routes:** build on `go/main.go` or `python/src/main.py`
5. **Extend CLAUDE.md:** add project-specific rules as your app grows
6. **Deploy:** update `deploy/helm/values.yaml` with your image + config

## Contributing

PRs welcome. All changes must pass `make check` and the PR security checklist.
