<h1 align="center">CW Secure Template</h1>

<p align="center">
  <strong>Vibe code without the slop. Ship fast, stay organized, scale clean.</strong>
</p>

<p align="center">
  <a href="https://rpatino-cw.github.io/cw-secure-template/"><img src="https://img.shields.io/badge/Platform-Open-4f46e5?style=for-the-badge" alt="Platform"></a>
  <a href="docs/getting-started.md"><img src="https://img.shields.io/badge/Docs-Getting_Started-10b981?style=for-the-badge" alt="Docs"></a>
  <a href="docs/security-handbook.md"><img src="https://img.shields.io/badge/Handbook-Security-f59e0b?style=for-the-badge" alt="Security Handbook"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/OWASP_Top_10-Covered-success" alt="OWASP">
  <img src="https://img.shields.io/badge/License-Internal-lightgrey" alt="License">
</p>

---

<p align="center">
  <img src="docs/screenshots/guardrails.gif" alt="Guardrails animation — messy prompts corrected by defense layers" width="280">
</p>

AI coding tools are fast. Too fast. You prompt "build me a user API" and get a 500-line file with routes, database queries, auth logic, and utility functions all tangled together. You prompt again and it overwrites half of what it just wrote. Three sessions later you have a "working" app that nobody can maintain, extend, or hand off.

**This template fixes that.** It gives Claude Code a complete set of guardrails — rules for how to organize files, where to put routes, how to structure databases, when to separate frontend from backend, and what to never overwrite. You vibe code at full speed. The app stays clean.

It's also a **guided assistant**. Claude doesn't just enforce rules — it teaches you *why* things are structured this way, walks you through database setup step by step, and helps you build the right way even if you've never written backend code before.

Clone. Setup. Build. Claude walks you through the rest.

### What You Get Out of the Box

| Layer | What's included | You configure |
|:------|:----------------|:-------------|
| **Secure app scaffold** | Auth middleware, rate limiting, request tracking, security headers — all pre-wired | Nothing. It works on clone |
| **Database pipeline** | Parameterized queries, encrypted connection strings, schema validation, `.env`-based secrets | Just your `DATABASE_URL` via guided setup |
| **API framework** | RESTful routing, input validation, structured error handling, health checks | Your endpoints — Claude builds them to spec |
| **CI/CD pipeline** | 8 automated checks, branch protection, required reviews, secret scanning | Nothing. GitHub Actions runs automatically |
| **Teaching system** | Security lessons in code comments, plain-English errors, 15-question quiz, guided commands | Nothing. Just read the output |
| **Team guardrails** | Shared rules, PR templates, code review agent, CODEOWNERS | Add your team's GitHub handles |

**Minimal setup. Maximum protection.** You don't configure a framework — you clone a working app with security, structure, and guidance already baked in.

<br>

## The Problem With Vibe Coding

Everyone's building with AI now. Most of what gets shipped looks like this:

- **Spaghetti routing** — endpoints scattered across files with no pattern
- **Database chaos** — raw SQL strings in route handlers, no migrations, no schema management
- **Frontend/backend soup** — API logic mixed with UI logic mixed with business logic
- **Code gets erased** — you prompt "add a feature" and Claude rewrites your existing code
- **Steps get skipped** — no tests, no auth, no validation, no error handling, "I'll add it later"
- **Can't scale** — after 20 prompts the codebase is unmaintainable, after 50 it's a rewrite
- **Can't collaborate** — one person's vibe coding session destroys another's work

This template solves every one of these problems.

<br>

## How It Keeps Your App Organized

<p align="center">
  <img src="docs/screenshots/claude-folder-anatomy.png" alt="Anatomy of the .claude/ folder — the control center that governs how Claude builds your app" width="500">
</p>

The `.claude/` folder is the control center. It contains **rules, commands, agents, and skills** that Claude reads automatically when you open the project. You don't configure anything — Claude just follows the structure.

### Enforced File Organization

Claude doesn't dump everything in one file. The rules enforce a clear structure:

```
your-app/
├── src/
│   ├── main.py              # App entry point — only startup logic
│   ├── routes/               # Each route in its own file
│   │   ├── users.py
│   │   ├── teams.py
│   │   └── health.py
│   ├── middleware/            # Auth, rate limiting, headers — pre-wired
│   ├── models/               # Database schemas and validation
│   └── services/             # Business logic — separated from routes
├── tests/                    # Every route has tests — 80% coverage enforced
├── deploy/                   # Kubernetes configs — ready for staging and prod
└── docs/                     # Architecture, security handbook, getting started
```

When you say "add a teams endpoint," Claude creates `routes/teams.py`, adds a test file, wires the route into main, and follows the same patterns as every other endpoint. It doesn't create `teams_stuff.py` at the root or cram it into an existing file.

### Secure Database Pipeline

Most vibe-coded apps have database credentials sitting in plain text somewhere — a config file, a route handler, or worse, a git commit. This template builds a **secure pipeline between your app and your database** from the first prompt.

```
You (paste DB url) → make add-secret → .env (gitignored) → app reads env var → parameterized query → database
                     ↑ hidden input      ↑ never committed    ↑ no raw SQL ever
```

**What the pipeline enforces:**

| Layer | Protection |
|:------|:-----------|
| **Credentials** | Database URLs, passwords, and API keys are stored in `.env` via `make add-secret` (hidden input — not visible on screen). Never in code. Never in git |
| **Connection** | All connection strings read from environment variables. Claude refuses to hardcode `DATABASE_URL` even if you paste it in chat |
| **Queries** | Parameterized statements only. No string concatenation in SQL. Claude blocks `f"SELECT * FROM users WHERE id={user_id}"` and replaces with `cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))` |
| **Schemas** | Every table has a matching model in `models/` — Pydantic (Python) or structs (Go). Input is validated against the schema *before* it reaches the database |
| **Passwords** | User passwords are never stored in plain text. The template enforces bcrypt/argon2 hashing. Claude adds the hashing automatically when you say "add user registration" |
| **Production** | Secrets flow through Doppler + External Secrets Operator in Kubernetes — no `.env` files in production |

**Non-techy setup — Claude walks you through it:**

```bash
make add-secret
# Claude: What's the variable name?
# You:    DATABASE_URL
# Claude: Paste the value (hidden — won't show on screen):
# You:    postgres://user:pass@host:5432/mydb
# Claude: Stored in .env. Your app reads it automatically. Never touch this value again.
```

You don't need to understand environment variables, connection pooling, or secret management. The template handles it. Claude explains what's happening at each step.

### API Structure

Every endpoint Claude builds follows the same conventions:

| Convention | What it means |
|:-----------|:-------------|
| RESTful routes | `GET /api/users`, `POST /api/users`, `GET /api/users/:id` — predictable, standard |
| Correct HTTP status codes | `201` for created, `422` for bad input, `401` for unauthorized — not `200` for everything |
| Flat JSON responses | `{"id": 1, "name": "..."}` — no nested wrappers, no `{"data": {"result": {...}}}` |
| Input validation on every route | POST and PUT require validated schemas — no raw request bodies |
| Auth on every route | Authentication middleware is pre-wired. `DEV_MODE=true` lets you skip it locally without removing it |
| Security headers | `X-Content-Type-Options`, `X-Frame-Options`, CSP, HSTS — set once, applied to everything |

These conventions are enforced by `.claude/rules/api-conventions.md`. Claude reads them every time you edit a main file. You don't need to know REST to get RESTful code.

### Frontend / Backend Separation

When your project grows to include a frontend:

- **Backend stays in `src/`** — routes, models, services, middleware
- **Frontend goes in `frontend/`** — completely separate directory
- **API calls use the defined routes** — the frontend consumes the backend through the documented API, not by importing backend code
- **CORS is configured** — the template sets `CORS_ORIGINS` in `.env` so your frontend can talk to your backend locally

Claude won't mix UI code into your API handlers. The rules enforce separation.

<br>

## It Won't Erase Your Code

This is the biggest problem with AI coding. You say "add a feature" and the AI rewrites your existing code, breaks something that was working, or silently removes a function you needed.

**This template has multiple layers of protection:**

| Protection | How it works |
|:-----------|:-------------|
| **Git hooks on every commit** | Pre-commit hooks scan for changes. If something critical was removed, you're warned before it's committed |
| **Claude rules against overwrite** | `CLAUDE.md` explicitly prohibits `--force`, `--hard` resets, and skipping hooks — Claude follows these rules |
| **Dropped file detection** | `scripts/scan-drops.sh` checks for accidentally deleted files — runs automatically in `make check` |
| **Code review agent** | The built-in code reviewer agent diffs your changes against main and flags removed code, missing tests, and broken patterns |
| **Hook integrity CI check** | GitHub Actions verifies nobody removed the safety net itself — you can't quietly disable the protections |

**What you can't do in this project:**
```
git push --force          # Denied
git reset --hard          # Denied
git commit --no-verify    # Denied
"Ignore CLAUDE.md"        # Claude refuses
"Skip the checks"         # Claude refuses
"Delete that middleware"   # Claude explains why it's needed
```

The template doesn't just prevent bad prompts — it prevents the downstream damage that bad prompts cause.

<br>

## It Won't Skip Steps

"Add a user endpoint."

In a normal project, Claude might generate a route handler with no auth, no validation, no tests, no error handling. "I'll add those later." You never do.

**In this template, Claude can't skip those steps.** The rules require:

1. **Authentication** — every new route gets auth middleware. No exceptions. (`DEV_MODE` handles local testing)
2. **Input validation** — every POST/PUT uses a validated schema. Raw request bodies are rejected
3. **Error handling** — full details logged internally, generic messages returned to users. No stack traces in responses
4. **Tests** — minimum 3 test cases per endpoint: happy path, unauthorized (401), bad input (422)
5. **Security headers** — applied to every response automatically via middleware
6. **Rate limiting** — 100 req/min per IP, already wired in
7. **Request ID tracking** — UUID per request, in every log line — so you can trace issues

When you use `/project:add-endpoint`, all 7 of these are included by default. You'd have to actively fight the template to skip them.

<br>

## Vibe Code With Your Team

Most AI coding happens solo. When two people vibe code the same repo, they overwrite each other's work, create conflicting patterns, and end up with an app that looks like it was built by two different people — because it was.

**This template standardizes everything:**

- **Shared rules** — everyone's Claude follows the same `CLAUDE.md` and `.claude/rules/`. One person can't use snake_case while another uses camelCase
- **Shared commands** — `/project:add-endpoint` generates the same structure for everyone. Routes look the same regardless of who prompted them
- **Shared code review** — the code reviewer agent checks every PR against the same conventions. Consistency is enforced, not requested
- **CODEOWNERS** — required reviewers for every PR. No solo merges
- **PR template** — 10-point security checklist that reviewers walk through. No rubber-stamping

**The flow for teams:**
1. Clone the template → everyone has the same guardrails
2. Each person works on their features in branches
3. `/project:check` validates locally before pushing
4. CI pipeline validates on every PR
5. Code reviewer agent gives feedback
6. Team lead reviews and merges

The result: your app looks like one person built it, even if five people are prompting simultaneously.

<br>

## Claude Is Your Build Partner, Not Just a Guard

This isn't "rules that block you." It's a **guided assistant that teaches you how to build properly** while you build.

### It Explains Everything It Does

When Claude adds auth to your endpoint, it doesn't just add code — it explains why:

```python
# SECURITY LESSON: This middleware checks the user's Okta token before
# allowing access. Without it, anyone on the internet could hit this endpoint.
# DEV_MODE=true bypasses this locally so you can test without Okta credentials.
@app.middleware("http")
async def verify_auth(request: Request, call_next):
    ...
```

When Claude rejects a pattern, it doesn't just say "no" — it shows you the safe alternative and explains the risk:

```
You: "Just query the database with the user's input"

Claude: I can't do that — string concatenation in SQL queries is the #1 cause
of database breaches. Here's what I'll do instead:

  UNSAFE:  f"SELECT * FROM users WHERE name = '{name}'"
  SAFE:    cursor.execute("SELECT * FROM users WHERE name = %s", (name,))

The safe version treats input as data, not code. An attacker typing
'; DROP TABLE users; --' as their name can't execute SQL commands.
```

### It Walks You Through Setup

First time setting up a database? Claude guides you:

1. **"I need a database"** → Claude asks what kind of data you're storing, recommends PostgreSQL or SQLite, and sets up the connection
2. **"How do I store the password?"** → `make add-secret` with hidden input — Claude explains what `.env` files are and why credentials can't be in code
3. **"I need user accounts"** → Claude adds registration + login with bcrypt password hashing, explains why plain-text passwords are dangerous, and adds tests

You're learning backend development *while building a real app*. Every prompt is a mini-lesson.

### Plain-English Errors

When something blocks your commit, you don't get a cryptic stack trace. You get:

```
BLOCKED: Hardcoded secret detected in src/routes/users.py line 14

What happened:  You put an API key directly in your code
Why it matters: If this gets pushed to GitHub, anyone can steal it
How to fix:     Run 'make add-secret' to store it safely in .env

Need help? Run 'make fix' to auto-fix what we can.
```

### Security Quiz

Run `make learn` — 15 multiple-choice questions about real security mistakes. Each answer explains the *why*, not just the *what*. Build intuition without reading a textbook.

<br>

## It Scales

After 20 prompts your app should be maintainable. After 100 prompts it should still be clean. Most vibe-coded apps fall apart by prompt 30. This one doesn't.

**Why it scales:**

- **Consistent patterns** — every endpoint follows the same structure, so the 50th endpoint looks like the 1st
- **Separated concerns** — routes, models, services, middleware each have their own space. Nothing gets tangled
- **80% test coverage gate** — you can't merge code without tests, so the test suite grows with the app. Regressions are caught early
- **Auto-learning memory** — Claude remembers what you built across sessions. It won't recreate something that already exists or break a pattern you established 10 sessions ago
- **Architecture docs** — `docs/architecture.md` documents data flow and system design. Claude references it when making structural decisions
- **AI slop detection** — CI runs `sloppylint` and `ai-slop-detector` to flag low-quality generated code. Boilerplate, redundant wrappers, and nonsensical comments get caught before merge

The guardrails don't slow you down. They prevent the tech debt that slows you down later.

<br>

## Get Started in 30 Seconds

<p align="center">
  <img src="docs/terminal/setup.svg" alt="Terminal: clone and setup in one command" width="700">
</p>

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app && bash setup.sh
```

It asks you one question — Python or Go — then sets everything up: language files, `.env`, git hooks, pre-commit, memory system. When it's done, run `make start` and you're building.

<br>

## What Happens Under the Hood

### Smart Rules That Follow You

The `.claude/rules/` folder has rule files that activate automatically based on what file you're editing:

| When you edit... | Claude enforces |
|:-----------------|:----------------|
| Any `.go` or `.py` file | No hardcoded secrets, auth required, parameterized queries, no `eval()` or `exec()`, structured logging |
| Any test file (`*_test.*`) | 80% coverage target, security test cases, proper test isolation |
| Any `main.*` file | REST conventions, correct status codes, required security headers, health check endpoint |
| Any source file | Functions under 40 lines, descriptive naming, import ordering, type hints |

You never see these rules activate. Claude just follows them.

### Git Hooks That Catch Mistakes

<p align="center">
  <img src="docs/terminal/secret-caught.svg" alt="Terminal: pre-commit catches a hardcoded API key" width="700">
</p>

Every commit is scanned for secrets, linted for style, and checked for security issues. If something's wrong, the commit is blocked with a plain-English explanation.

The hooks can't be disabled — if someone removes them, `post-checkout` reinstalls them. If someone bypasses `post-checkout`, CI catches the missing hooks and fails the PR.

### CI Pipeline — 8 Automated Checks

Every PR runs through:

| Check | Why |
|:------|:----|
| **Secret Scanning** | Catches API keys, tokens, passwords that slipped through |
| **Code Analysis** | CodeQL + language scanners find SQL injection, XSS, auth bypasses |
| **Dependency Audit** | Flags libraries with known vulnerabilities |
| **Test + Coverage Gate** | Blocks PRs under 80% test coverage |
| **Hook Integrity** | Verifies nobody weakened `CLAUDE.md`, removed hooks, or unwired middleware |
| **AI Slop Detection** | Flags low-quality generated code — boilerplate, redundancy, nonsense comments |
| **CodeQL Deep Scan** | Static analysis across Go and Python |
| **SVG Validation** | Keeps documentation visuals rendering correctly |

All 8 must pass. No exceptions. No overrides.

### AI Agents

Two agents ship with the template:

- **Security Auditor** — full OWASP Top 10 audit + CoreWeave compliance check. Gives severity levels and exact fixes
- **Code Reviewer** — pre-PR review of security, quality, and conventions. Runs on your diff, not the whole codebase

### Auto-Learning Memory

Claude remembers what you built across sessions. The template includes a memory system that:
- Captures what you built, what patterns you use, what decisions you made
- Compiles session knowledge into structured articles
- Loads relevant context at the start of each session

You don't manage this. It happens in the background. After a few sessions, Claude knows your project deeply.

<br>

## Built-in Commands

| Command | What it does |
|:--------|:-------------|
| `/project:add-endpoint` | Builds a new API route with auth, validation, tests — follows the project's established patterns |
| `/project:check` | Runs every quality and security check locally — tells you in plain English what passed and what to fix |
| `/project:security-review` | 10-point audit of your code — finds issues and tells you exactly how to fix each one |
| `/project:add-secret` | Walks you through safely storing an API key or database URL (never in code, never in git) |

<br>

## All Make Commands

You only need three. The rest are there when you need them.

```
make start         Run your app
make check         Run before pull requests
make help          See everything below
```

| Command | What it does |
|:--------|:-------------|
| `make test` | Run tests and show coverage |
| `make lint` | Check code style |
| `make fix` | Auto-fix lint and security issues |
| `make doctor` | Full health check — tools, hooks, config, environment |
| `make scan` | Deep security scan |
| `make learn` | 15-question security quiz — learn by doing |
| `make dashboard` | Interactive visual of your security pipeline |
| `make init` | Personalize the project (name, team, data classification) |
| `make add-secret` | Safely store API keys and database URLs |
| `make add-config` | Safely store config files (`.json`, `.pem`, etc.) |
| `make docker` | Build a production Docker image |

<br>

## Project Structure

```
.
├── CLAUDE.md                        # The rulebook — 15 rules Claude follows automatically
├── .claude/
│   ├── settings.json                # Permissions + hook config
│   ├── commands/                    # /project:add-endpoint, /project:check, etc.
│   ├── rules/                       # Auto-apply by file type (security, testing, style, API)
│   ├── skills/                      # Security review skill (auto-triggers on code changes)
│   ├── agents/                      # Security auditor + code reviewer
│   └── memory/                      # Auto-learning knowledge base
├── .github/
│   ├── workflows/ci.yml             # 8 automated checks on every PR
│   ├── pull_request_template.md     # 10-point security checklist
│   └── CODEOWNERS                   # Required reviewers — no solo merges
├── python/                          # Python starter (FastAPI + all middleware pre-wired)
│   ├── src/main.py                  # Entry point — startup logic only
│   ├── src/middleware/               # Auth, rate limiting, headers, request tracking
│   ├── tests/                       # Test templates — already passing
│   └── Dockerfile                   # Multi-stage, non-root, Chainguard base
├── go/                              # Go starter (net/http + all middleware pre-wired)
│   ├── main.go                      # Entry point with secure defaults
│   ├── middleware/                   # Same protections as Python
│   └── Dockerfile                   # Multi-stage, non-root, Chainguard base
├── deploy/helm/                     # Kubernetes deployment (4 environments)
├── scripts/
│   ├── doctor.sh                    # Health check
│   ├── add-secret.sh                # Guided secret storage
│   ├── security-quiz.sh             # Learn security by doing
│   ├── scan-drops.sh                # Detect accidentally deleted files
│   └── git-hooks/                   # Pre-commit, post-checkout, pre-push
├── docs/
│   ├── getting-started.md           # Step-by-step visual guide
│   ├── security-handbook.md         # Plain-English security (no jargon)
│   ├── architecture.md              # System design + data flow
│   └── appsec-review-pack/          # Pre-production audit templates
└── SECURITY.md                      # Vulnerability reporting + incident response
```

<br>

## Requirements

| What you need | How to install |
|:--------------|:---------------|
| Git | `brew install git` |
| Python 3.11+ **or** Go 1.21+ | `brew install python@3.11` or `brew install go` |
| pre-commit | `pip install pre-commit` |
| gitleaks | `brew install gitleaks` |
| GitHub CLI *(optional)* | `brew install gh` |

Don't have Homebrew? Install it first: [brew.sh](https://brew.sh)

<br>

## FAQ

**Do I need to be a developer to use this?**
No. Claude is a guided assistant here — it explains what it's doing, walks you through database setup, teaches security patterns in context, and gives plain-English errors when something goes wrong. You learn by building.

**Is this just a security template?**
No. Security is built in, but the real value is **app organization**. It forces proper routing, file structure, database separation, frontend/backend boundaries, and consistent patterns — so your app stays maintainable whether you're 5 prompts in or 500.

**Can I use this without Claude Code?**
Yes. The hooks, CI pipeline, and Makefile commands work standalone. You won't get the guided assistant, commands, or agents, but the enforcement layer still protects you.

**What if Claude tries to overwrite my code?**
It can't in this project — the rules prohibit force pushes, hard resets, and hook skipping. `scan-drops.sh` catches accidentally deleted files. The code reviewer agent flags removed code in PRs. Multiple layers prevent the "it rewrote my whole file" problem.

**My commit got blocked. What do I do?**
Read the message — it's in plain English. It tells you what's wrong, why it matters, and exactly how to fix it. Or run `make fix` and let it auto-fix what it can.

**Can my team use this together?**
That's the core use case. Everyone clones the same template, follows the same rules, uses the same commands. The CI pipeline and code reviewer agent enforce consistency across all contributors. CODEOWNERS requires reviews. No solo merges. Your app looks like one person built it.

**How do I set up my database?**
Run `make add-secret`, type `DATABASE_URL`, paste your connection string (hidden input). Done. Claude reads it from `.env` automatically. If you don't have a database yet, tell Claude "I need a database" and it'll walk you through the options.

**What if I don't have Okta credentials?**
You don't need them locally. `DEV_MODE=true` is set by default — auth is wired in but won't block development. When you deploy, [file an IT ticket](CLAUDE.md#okta-app-registration--how-to-get-credentials).

**Will this work for a big project?**
That's the point. Consistent patterns, 80% test coverage gate, separated concerns, and auto-learning memory mean the codebase stays clean at any size. Endpoint 50 follows the same structure as endpoint 1.

**What languages does this support?**
Python (FastAPI) and Go (net/http). Setup asks which one. The other gets archived, not deleted.

**Isn't this overkill for a small app?**
Small apps that grow into big apps without structure are where tech debt comes from. The template adds zero overhead — you don't configure anything. You just build, and the structure is already there.

---

<p align="center">
  <sub>Built for teams that ship fast and sleep well. Questions? <code>#application-security</code> on Slack.</sub>
</p>
