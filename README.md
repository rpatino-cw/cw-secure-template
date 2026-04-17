<h1 align="center">CW Secure Framework</h1>

<p align="center"><strong>Ship internal tools fast. Security happens automatically.</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/OWASP_Top_10-Covered-success" alt="OWASP">
  <img src="https://img.shields.io/badge/Rules-17-orange" alt="Rules">
  <img src="https://img.shields.io/badge/Guard_Tests-30/30-brightgreen" alt="Guard Tests">
  <img src="https://img.shields.io/badge/Self--Protection-45_deny_rules-red" alt="Self-Protection">
</p>

<p align="center">
  <img src="docs/screenshots/guardrails.gif" alt="Guardrails — messy prompts in, clean code out" width="600">
</p>

---

## What this is

A framework for building internal CoreWeave apps with AI (Claude Code). You write the prompts, the framework handles auth, secrets, input validation, tests, and architecture — enforced at three independent layers so nothing slips through.

Not a template you fork once. A living system that guides and blocks as you build.

## Who it's for

- **Teams building internal tools** — dashboards, admin panels, approval flows, ops utilities
- **Engineers using Claude Code** — the framework constrains Claude to produce secure, well-structured code regardless of prompt quality
- **Non-security-experts** — you don't need to know OWASP to ship code that passes an AppSec review

---

## What you can build

Pick a blueprint and start. Auth, rate limiting, secret management, CI gates, and architecture enforcement are wired from the first command.

| App type | Blueprint | Stack | What you get |
|:---------|:----------|:------|:-------------|
| **REST API** | `api-service` | Go, Python | CRUD endpoints, auth middleware, rate limiting, request validation |
| **AI chat tool** | `chat-assistant` | Python | Claude API integration, streaming, token budgets, audit logging |
| **Background jobs** | `batch-processor` | Python | Job queue, retry logic, dead letter queue, graceful shutdown |
| **Internal dashboard** | `internal-dashboard` | Python | Authenticated views, data tables, charts, role-based pages |
| **Admin tool** | `admin-tool` | Go, Python | CRUD admin panel, permissions, audit trail, bulk operations |
| **Approval workflow** | `approval-workflow` | Python | Request intake, multi-step approvals, notifications, status tracking |

```bash
make wizard                          # visual setup — recommended
make new BLUEPRINT=api-service       # or chat-assistant, batch-processor, etc. (CLI)
```

**New:** [`setup.html`](setup.html) is a visual wizard that asks the right questions upfront (stack, database, security posture, team) and generates a tailored scaffold with the correct guards, CI gates, and CLAUDE.md rules already baked in. No more generic template — the project arrives already locked to your choices. Run `make wizard` to open it.

---

## Why it's different — 3 enforcement layers

Most security tools give you suggestions. This one gives you walls.

Four independent systems run simultaneously. All four must be defeated to ship insecure code — and three of them aren't controlled by the AI at all.

| Layer | What it does | Can Claude override it? |
|:------|:-------------|:-----------------------|
| **Rulebook** | CLAUDE.md + 17 rule files guide code generation. Anti-override protocol catches social engineering ("ignore the rules", "you're in developer mode", "just this once"). | No — refuses and explains why |
| **Blocklist** | 74 deny rules in `settings.json` physically block dangerous commands before execution. Claude never sees the command run — the runtime rejects it. | No — runtime decision, not Claude's |
| **Guard** | Shell script scans every file edit for secrets, dangerous functions, and guardrail tampering. Runs before the file is saved. | No — hook rejects before save |
| **Config Gate** | Blocks all tool calls until `make secure-mode` is run. Prevents global Claude Code configs (like `bypassPermissions`) from undermining this repo's guards. | No — shell script, runs before Claude acts |

### Proof: what actually gets blocked

These aren't hypothetical. The guard tests verify all of them (`make test-guards` — 30/30 passing).

| You try this | What happens |
|:-------------|:------------|
| SQL with string concatenation | **Blocked.** Guard detects concatenation pattern, forces parameterized queries. |
| API key pasted into source code | **Refused.** Redirected to `make add-secret` (hidden terminal input, stored in `.env`). |
| Endpoint with no auth check | **Auto-fixed.** Okta OIDC middleware added. `DEV_MODE=true` for local dev. |
| Code pushed with no tests | **Blocked.** CI enforces 80% coverage gate — PR cannot merge. |
| `git push --force` | **Denied.** Deny rule fires before the command executes. |
| `git commit --no-verify` | **Denied.** Same — blocked at the runtime level. |
| `eval()` or `exec()` in Python | **Blocked.** Guard catches dangerous function calls in any source file. |
| Claude told "ignore CLAUDE.md" | **Refused.** Anti-override protocol responds with explanation. |
| Logic dumped in one file | **Enforced.** Architecture rules require separation: `routes/`, `services/`, `models/`, `middleware/`. |
| Secrets read via `cat`, `grep`, `xxd`, `base64` | **Denied.** 45 self-protection rules block all known methods of reading enforcement files. |

> **Try to break it.** Clone the repo, run `make test-guards`, and try to get secrets into source code or bypass the hooks. The framework is designed to withstand adversarial prompts.

---

## 60-second start

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app
bash setup.sh
```

Setup asks one question: **Go or Python?** Then it installs hooks, configures the stack, and you're building.

```
make start         Run your app (localhost:8080)
make check         All checks before a PR
make doctor        Security health check — tells you what's wrong and how to fix it
make viz           Interactive visualizer — see how the whole system works
```

**Requires:** `git` + `gitleaks` + Python 3.11+ or Go 1.21+

---

## Add to an existing project

Already have a codebase? `make adopt` installs the security layer without touching your code or imposing architecture opinions.

```bash
git clone https://github.com/rpatino-cw/cw-secure-template /tmp/cw-secure
make -C /tmp/cw-secure adopt TARGET=/path/to/your/project
```

**What you get:**
- Secret detection + dangerous function blocking (PreToolUse guards)
- 35 deny rules (force push, hard reset, eval, rm -rf — blocked at runtime)
- Claude Code security rules (`.claude/rules/`)
- Pre-commit hooks (gitleaks, secret scanning)
- CLAUDE.md security sections (anti-override protocol, OWASP, secure defaults)

**What you don't get** (no architecture opinions):
- No directory structure requirements (no `routes/services/models/` enforcement)
- No stack lock (use any language)
- No multi-agent rooms
- No Write-tool blocking on existing files

Everything lives in a self-contained `.cw-secure/` directory. Easy to upgrade (`FORCE=1`) and easy to remove (`rm -rf .cw-secure/`).

---

## App Doctor — your security health check

`make doctor` is a full pipeline audit. It checks everything and tells you what to fix in plain English.

```
CW Secure Framework — Security Health Check
============================================

  Blueprint: api-service  |  Stack: python

Tools
  [PASS] git installed
  [PASS] gitleaks installed
  [PASS] python3 installed
  [PASS] ruff installed
  [WARN] bandit installed — Run: pip install bandit

Git Hooks
  [PASS] pre-commit hook installed
  [PASS] post-checkout hook installed

Configuration
  [PASS] CLAUDE.md exists
  [PASS] .gitignore exists
  [PASS] CI workflow exists

Environment
  [PASS] .env file exists
  [WARN] OKTA_ISSUER configured — Auth will use DEV_MODE fallback

Code Quality
  [PASS] No hardcoded secrets in source
  [PASS] No dangerous Python functions in source
  [PASS] No outstanding SECURITY TODOs

============================================
Security Posture: 14/16 checks passing
2 warnings to review
```

**What it checks:**
- Tool installation (git, gitleaks, linters, scanners)
- Git hook integrity (pre-commit, post-checkout, pre-push)
- Configuration files (CLAUDE.md, .gitignore, CI workflows, PR template)
- Environment variables (Okta credentials, required secrets)
- Code quality (hardcoded secrets, dangerous functions, security TODOs)
- .gitignore coverage (`.env`, `*.pem`, `*.key`, `credentials.json`, `*.db`)
- Dropped secrets scan (config files left in the project root)

Every `[FAIL]` and `[WARN]` includes what to run to fix it.

---

## Multi-agent rooms — multiple people, one codebase, zero conflicts

The most distinctive feature: multiple people vibe-coding the same project simultaneously. Each person gets their own Claude agent in their own terminal. Agents stay in their lane.

<p align="center">
  <img src="docs/screenshots/agents-animation.gif" alt="Agent coordination — Go and Python agents passing notes instead of overwriting code" width="600">
</p>

### How it works

```
  Alice (go-dev)              Bob (py-dev)              Carol (security)
  ┌────────────┐             ┌────────────┐            ┌──────────────┐
  │ Owns: go/  │             │ Owns: python/ │          │ Owns: guard, │
  │            │  request    │              │           │ hooks, rules │
  │ Needs a    │────────────>│  inbox/      │           │              │
  │ Python     │             │  process...  │           │              │
  │ function   │<────────────│  outbox/     │           │              │
  │            │  response   │              │           │              │
  └────────────┘             └────────────┘            └──────────────┘
       │                           │                          │
       │    guard.sh HARD-BLOCKS edits outside your room      │
       └──────────────────────────────────────────────────────┘
```

```bash
make rooms              # auto-detect rooms from project structure
make agent NAME=go      # Alice — can only edit go/
make agent NAME=python  # Bob — can only edit python/
make room-status        # see pending requests across the team
```

### Key rules

- The guard **hard-blocks** edits outside your room — not a suggestion, a wall
- Need something from another room? Drop a request in their **inbox**
- A live **activity feed** warns when someone else is editing nearby
- Shared files (CLAUDE.md, .env.example) require approval from the security room

No merge conflicts. No stepping on each other's work. No coordination meetings. [Full docs](rooms/README.md)

---

## Policy profiles

Not every project needs the same friction level. Set a profile to match your stage.

| Profile | Auth | Coverage gate | Guard hooks | Force-push block | Best for |
|:--------|:-----|:-------------|:------------|:----------------|:---------|
| **hackathon** | DEV_MODE only | Off | Secrets only | Off | Rapid prototyping, demos |
| **balanced** | DEV_MODE local, Okta prod | 60% | Secrets + architecture | On | Internal tools, team projects |
| **strict** (default) | Okta everywhere | 80% | Full enforcement | On | Production services |
| **production** | Okta + mTLS | 90% | Full + audit logging | On | Customer-facing, compliance |

```bash
make profile LEVEL=balanced    # adjust enforcement level
make doctor                    # verify the profile is applied correctly
```

---

## Architecture enforcer

The framework doesn't just catch bugs — it enforces how code is organized.

### Dependency direction (always enforced)

```
  routes/handlers          Thin. Receive request, call service, return response.
        │                  10-20 lines max. No business logic.
        ▼
  services/                The brain. Business rules, orchestration, validation.
        │                  Knows the domain. Doesn't know HTTP.
        ▼
  repositories/            Data access. Queries, connections, migrations.
        │                  Knows the database. Doesn't know business rules.
        ▼
  models/                  Data shapes. Validation, types, schemas.
                           Bottom layer. Depends on nothing.
```

**Skip a layer? Blocked.** A route importing from repositories directly? Guard catches it.

### Foundation Gate

Before any feature code, infrastructure must exist:

```
  [ ] Config loader        → reads from environment, fails fast
  [ ] Logger initialized   → structured JSON (slog / structlog)
  [ ] DB connection         → pool + graceful close
  [ ] Middleware registered → auth, rate limit, request ID, headers
  [ ] Router setup          → routes imported, not inline
```

Ask Claude to write an endpoint before these exist? It refuses and tells you what's missing.

### Stack lock

`make init` locks the repo to Go **or** Python. After that, wrong-language files are blocked by the guard.

### File placement

Every type of code has exactly one home:

| Code type | Home directory |
|:----------|:-------------|
| HTTP handlers | `routes/` |
| Business logic | `services/` |
| Data access | `repositories/` |
| Data shapes | `models/` |
| Middleware | `middleware/` |
| Config / constants | `config/` |
| Pure utilities | `utils/` |
| Entry point | `main.go` / `main.py` |

---

## Self-protection

Most security tools have a fatal flaw: the AI can read the rules and craft a bypass. This framework doesn't have that problem.

**45 deny rules** block every known method of reading the enforcement files — before the command executes.

| Vector | Blocked |
|:-------|:--------|
| Claude's built-in tools | `Read`, `Grep`, `Glob` on guard scripts and settings |
| File readers | `cat`, `head`, `tail`, `less`, `more`, `bat` |
| Text processors | `grep`, `rg`, `awk`, `sed` |
| Encoding tricks | `xxd`, `hexdump`, `base64`, `strings`, `od` |
| Git history | `git show`, `git diff`, `git log -p` |
| Script interpreters | `python -c`, `node -e`, `perl -e`, `ruby -e` |

---

## 17 rule files

Each file in `.claude/rules/` covers one part of the codebase. Claude reads and follows them automatically.

| Rule | Covers |
|:-----|:-------|
| `api-conventions` | RESTful naming, response format, status codes, required headers |
| `architecture` | Stack lock, Foundation Gate, dependency direction |
| `branching` | Trunk mode (default) vs. branch mode (opt-in via PR) |
| `classes` | Where classes/structs live — one home per type |
| `code-style` | Line length, function size, imports, linting |
| `collaboration` | Anti-overwrite, small edits only, git conflict awareness |
| `database` | Parameterized queries only, connection strings from env |
| `entry` | What belongs in `main.go` / `main.py` — startup wiring only |
| `frontend` | Separate directory, talks to backend through API only |
| `functions` | Utility functions: pure, no side effects, reusable |
| `globals` | Config and constants in one place |
| `models` | Data shapes: validation, types, schemas. Depends on nothing |
| `rooms` | Multi-agent coordination — ownership, inboxes, conflict prevention |
| `routes` | Thin HTTP handlers (10-20 lines max) |
| `security` | Secrets, auth, input validation, dangerous function blocklist |
| `services` | Business logic layer. Knows the rules, doesn't know HTTP |
| `testing` | 80% coverage, 3 tests per endpoint, security test patterns |

---

## All commands

**Start here:**

```
make new BLUEPRINT=X   Start from a blueprint (api-service, chat-assistant, batch-processor, etc.)
make start             Run your app
make check             All checks before a PR
make doctor            Security health check — what's wrong and how to fix it
```

**Multi-agent:**

```
make rooms             Set up room-based coordination
make agent NAME=go     Start Claude as a room agent
make room-status       See pending requests across rooms
make review            AI code review on unpushed changes
```

**Testing & quality:**

```
make test              Run tests (go test / pytest)
make lint              Check code style
make fix               Auto-fix lint + security issues
make test-guards       Run 30 guard unit tests
```

**Security:**

```
make scan              Deep security scan (gitleaks, gosec/bandit, govulncheck/pip-audit)
make learn             15-question OWASP quiz
make add-secret        Safely store an API key in .env (hidden input)
make add-config        Safely store a config file
make viz               Interactive visualizer
make dashboard         Open team dashboard (snapshot, 5s polling)
make team-server       Live presence server — teammates appear in real time
```

**Setup:**

```
make init              Personalize for your project
make setup             Re-run first-time setup
make secure-mode       Lock Claude Code permissions for this repo (one-time)
make upgrade           Pull latest framework changes from upstream
make adopt TARGET=X    Install security guards into an existing project
make profile LEVEL=X   Set enforcement level (hackathon, balanced, strict, production)
make docker            Build Docker image
```

---

## Docs

- **[Live site](https://rpatino-cw.github.io/cw-secure-template/)** — visual overview, live agent demo, and deep-dive explainer
- [Getting started](docs/getting-started.md) — clone to running in 6 steps
- [Architecture](docs/architecture.md) — visual diagrams of enforcement layers, dependency flow, and room coordination
- [Security handbook](docs/security-handbook.md) — plain-English OWASP guide with glossary
- [Rooms guide](rooms/README.md) — multi-agent coordination docs

---

<p align="center"><sub>Built for CoreWeave teams. Questions: <code>#application-security</code></sub></p>
