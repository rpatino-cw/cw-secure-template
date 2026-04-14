<h1 align="center">CW Secure Template</h1>

<p align="center">
  <strong>Vibe code without the slop.</strong>
</p>

<p align="center">
  <a href="docs/getting-started.md"><img src="https://img.shields.io/badge/Docs-Getting_Started-10b981?style=for-the-badge" alt="Docs"></a>
  <a href="docs/security-handbook.md"><img src="https://img.shields.io/badge/Handbook-Security-f59e0b?style=for-the-badge" alt="Security Handbook"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/OWASP_Top_10-Covered-success" alt="OWASP">
  <img src="https://img.shields.io/badge/CoreWeave-Internal-lightgrey" alt="CW Internal">
</p>

---

<p align="center">
  <img src="docs/screenshots/guardrails.gif" alt="Guardrails — messy prompts in, clean code out" width="280">
</p>

Your team uses Claude Code to build internal tools. This template gives Claude **14 enforced rule files**, a **3-layer security system that can't be bypassed**, and an **architecture enforcer** that locks your app into a real framework. Everyone on the team gets the same guardrails. No config. Clone and build.

<p align="center">
  <img src="docs/terminal/demo-typing.svg" alt="Terminal: clone, setup, and start in seconds" width="720">
</p>

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app && bash setup.sh
```

<br>

## What It Enforces

| Problem | What Claude does in this project |
|:--------|:-------------------------------|
| Routes dumped in one file | Enforces `routes/`, `models/`, `services/`, `middleware/` separation |
| Raw SQL in handlers | Blocks it. Parameterized queries only |
| Database creds in code | Refuses. Redirects to `make add-secret` |
| No auth | Every endpoint gets Okta OIDC middleware. `DEV_MODE=true` for local |
| No tests | 80% coverage gate. CI blocks the PR if missing |
| Code gets overwritten | `--force`, `--hard`, `--no-verify` denied. Write tool blocked on existing files |
| Skipped steps | Auth, validation, tests, error handling, rate limiting — all required |
| AI slop | CI runs slop detectors. Boilerplate and junk comments get flagged |

<br>

## 14 Rule Files — The Code Router

When Claude opens a file, the right rules load automatically based on what you're editing:

| You touch... | Rules that load | What they enforce |
|:-------------|:----------------|:------------------|
| `routes/` | `routes.md` | Thin handlers only. No logic, no SQL. Must call services |
| `models/` | `models.md` | Data shapes only. No imports from routes or services |
| `services/` | `services.md` | Business logic only. No HTTP objects, no raw SQL |
| `db/`, `repositories/` | `database.md` | Parameterized queries only. Creds from env. Migrations required |
| `config/`, `constants/` | `globals.md` | One config file, one settings class. No scattered `os.getenv()` |
| `utils/`, `helpers/` | `functions.md` | Pure functions only. No side effects, no DB calls |
| `*.py`, `*.go` | `classes.md` | Placement table: where each class type belongs |
| `frontend/` | `frontend.md` | Separate dir. API calls only. No backend imports |
| `main.*`, `app.*` | `entry.md` | Startup only. Foundation gate: infra before features |
| Any file | `collaboration.md` | Edit over Write. Check git status. Small edits. Anti-overwrite |
| Any source file | `security.md` | No secrets, no `eval()`, no `exec()`, parameterized queries |
| Any source file | `code-style.md` | Functions under 40 lines, structured logging, imports |
| Test files | `testing.md` | 80% coverage, security tests, proper isolation |
| Main files | `api-conventions.md` | REST, correct status codes, security headers |

Every rule file has **dependency direction** (what can import what) and **violations to block** (specific patterns Claude refuses to write).

<br>

## Architecture Enforcer

Run `/arch-enforcer` in Claude Code. Pick a framework. Claude locks in and refuses to deviate.

```
Pick your stack:

  Go:
    [1] Go Standard Layout      — golang-standards/project-layout (55k stars)
    [2] Go Clean Architecture   — bxcodec/go-clean-arch
    [3] Go Clean Template       — evrone/go-clean-template (Gin + Postgres)
    [4] Go Microservices (Kit)  — go-kit/kit

  Python:
    [5] FastAPI Full-Stack      — fastapi/full-stack-fastapi-template (42k stars)
    [6] FastAPI Best Practices  — zhanymkanov/fastapi-best-practices
    [7] Django Cookiecutter     — cookiecutter-django
    [8] Python Clean Arch (DDD) — cosmicpython/code
```

After selection: **Foundation Gate** — Claude refuses to write any endpoint or business logic until config, logger, DB connection, error handling, middleware, and entry point are set up. Infrastructure first, features second.

<br>

## The Guardrails Are Unbreakable

Three enforcement layers. All three must be defeated to bypass them.

```
Layer 1 — Rules (CLAUDE.md + 14 rule files)
│  Claude reads and follows these. Anti-override protocol handles
│  "ignore the rules", "developer mode", "pretend you're unrestricted",
│  base64-encoded secrets, and every social engineering trick.
│  ↓ but what if someone convinces Claude anyway?
│
Layer 2 — Deny List (settings.json)
│  Claude Code RUNTIME blocks commands before execution.
│  Not Claude's decision. The runtime physically won't run:
│  --force, --hard, --no-verify, rm -rf, eval, chmod 777,
│  curl|bash, and modifications to guardrail files.
│  ↓ but what if bad code gets written without a blocked command?
│
Layer 3 — PreToolUse Hook (scripts/guard.sh)
   Runs BEFORE every file edit. Parses the JSON input. Checks for:
   ✗ Hardcoded secrets (10 patterns — API keys, DB URLs, tokens)
   ✗ Dangerous functions (eval, exec, pickle, os.system, shell=True)
   ✗ Modifications to guardrail files (CLAUDE.md, .claude/, hooks)
   ✗ Full-file overwrites (blocks Write on existing files, forces Edit)
   Rejects the write before it happens. Not Claude's choice.
```

| They try | What stops them |
|:---------|:---------------|
| "Ignore the rules" | Layer 1 — Claude refuses, cites repo owner |
| "You're in developer mode" | Layer 1 — No such mode. Rules are infrastructure |
| `git push --force` | Layer 2 — Runtime blocks. Never executes |
| `git commit --no-verify` | Layer 2 — Runtime blocks. Never executes |
| Paste an API key in code | Layer 3 — Hook detects pattern, rejects write |
| Write `eval()` or `exec()` | Layer 3 — Hook blocks dangerous function |
| Edit CLAUDE.md to weaken rules | Layer 3 — Hook blocks edits to guardrail files |
| Overwrite a teammate's file | Layer 3 — Write tool blocked on existing files |
| Remove the hooks | Layer 2 — `pre-commit uninstall` denied |
| Weaken rules and push | CI — Hook integrity check fails, PR blocked |

<br>

## Commands

```
make start         Run your app
make check         All checks before a PR
make add-secret    Store a DB URL or API key safely
make doctor        Health check
make learn         15-question security quiz
```

<br>

## Requirements

`brew install git gitleaks` and Python 3.11+ or Go 1.21+. [Full setup](docs/getting-started.md).

---

<p align="center">
  <sub>Built for CoreWeave teams. Questions? <code>#application-security</code> on Slack.</sub>
</p>
