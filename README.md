<h1 align="center">CW Secure Template</h1>

<p align="center">
  <strong>Same prompt. Secure code. Zero extra work.</strong>
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

**Same prompt. Secure code. Zero extra work.**

Your team prompts Claude to build internal tools. This template makes every line of code production-safe — authentication, secret management, input validation, and tests are enforced automatically. Six layers of defense between your code and production. Nothing ships without passing all of them.

Clone. Setup. Build. The security infrastructure is already there.

<br>

## Get Started in 30 Seconds

<p align="center">
  <img src="docs/terminal/setup.svg" alt="Terminal: clone and setup in one command" width="700">
</p>

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app && bash setup.sh
```

It asks you one question — Python or Go — then sets everything up. When it's done, run `make start` and you're building.

<br>

## What Makes This Different

Most templates give you starter code. This one gives you a **full Claude Code framework** — rules, commands, agents, and a GitHub Actions pipeline that enforces security even when nobody's watching.

### Claude Already Knows the Rules

The template includes a `CLAUDE.md` file with 15 security rules. When you open Claude Code in this project, it reads those rules automatically. You don't configure anything.

**What this means in practice:**
- You say "add an endpoint for team members" — Claude adds authentication, input validation, and tests without you asking
- You paste an API key into the chat — Claude **refuses** to put it in your code and tells you how to store it safely
- You say "skip auth, I'll add it later" — Claude keeps auth wired in but gives you a test mode so it doesn't block local development
- You say "just make it work" — Claude makes it work **and** makes it secure, because in this project they're the same thing

### Built-in Commands

Type these directly in Claude Code:

| Command | What it does |
|:--------|:-------------|
| `/project:add-endpoint` | Builds a new API route with auth, validation, and tests already wired |
| `/project:check` | Runs every quality and security check — tells you in plain English what passed and what to fix |
| `/project:security-review` | 10-point security audit of your code — finds issues, tells you exactly how to fix each one |
| `/project:add-secret` | Walks you through safely storing an API key (never in code, never in git) |

### AI Agents That Review Your Code

Two agents ship with the template. They run inside Claude Code and act like a second pair of eyes:

- **Security Auditor** — checks your code against the OWASP Top 10 and CoreWeave compliance rules. Outputs a report with severity levels and exact fixes.
- **Code Reviewer** — reviews your changes before you open a PR. Checks security, code quality, and project conventions. Tells you what to fix and what looks good.

### Smart Rules That Follow You

The `.claude/rules/` folder has 4 rule files that activate automatically based on what file you're editing:

| When you edit... | These rules apply |
|:-----------------|:------------------|
| Any `.go` or `.py` file | No hardcoded secrets, auth required, parameterized queries, no dangerous functions |
| Any test file (`*_test.*`) | 80% coverage target, security tests required, proper test environment setup |
| Any `main.*` file | REST conventions, correct status codes, required security headers |
| Any source file | Code style, structured logging, import ordering |

You never see these rules. Claude just follows them.

<br>

## What Happens When You Commit

The template installs git hooks that run automatically. You don't configure them — they're just there.

<p align="center">
  <img src="docs/terminal/secret-caught.svg" alt="Terminal: pre-commit catches a hardcoded API key" width="700">
</p>

**Hardcoded a secret?** Blocked. The hook tells you what file and line, then shows you how to store it safely.

This isn't a warning you can ignore — the commit doesn't happen until the issue is fixed.

<br>

## GitHub Actions — The Enforcement Layer

This is the backbone. Every time you push code or open a pull request, GitHub Actions runs **6 automated checks** on your code. You can't skip them, you can't turn them off, and your PR can't merge until they all pass.

| Check | What it does | Why it matters |
|:------|:-------------|:---------------|
| **Secret Scanning** | Scans every file for API keys, tokens, and passwords | Catches secrets that slipped past the git hooks |
| **Code Analysis** | Runs CodeQL + language-specific scanners (gosec for Go, bandit for Python) | Finds security bugs that humans miss — SQL injection, XSS, auth bypasses |
| **Dependency Audit** | Checks every library your code uses for known vulnerabilities | A single outdated library can compromise your whole app |
| **Test + Coverage Gate** | Runs all tests and **blocks the PR if coverage drops below 80%** | Untested code is where bugs hide |
| **Hook Integrity** | Verifies nobody removed the security hooks, weakened CLAUDE.md rules, or unwired security middleware | Prevents someone from quietly disabling the safety net |
| **SVG Validation** | Checks that documentation visuals render correctly | Keeps the docs looking right |

**If a check fails**, you'll see a clear message in your pull request explaining what went wrong and how to fix it. No cryptic error codes.

**If all checks pass**, your code is safe to merge. That's the promise.

<br>

## Health Check

Not sure if everything's working? Run one command.

<p align="center">
  <img src="docs/terminal/doctor.svg" alt="Terminal: make doctor health check output" width="700">
</p>

`make doctor` checks your tools, hooks, config files, environment, code quality, and secret exposure. Green across the board = you're good.

<br>

## Before You Open a Pull Request

Run `make check`. It does everything the CI pipeline does, but locally — so you know it'll pass before you push.

<p align="center">
  <img src="docs/terminal/make-check.svg" alt="Terminal: make check runs all pre-PR checks" width="700">
</p>

<br>

## Auto-Learning Memory

The template includes an automatic memory system. When you use Claude Code in this project, it learns from each session — what you built, what patterns you use, what decisions you made. Next time you open Claude Code, it already has that context.

You don't manage this. It happens in the background. Over time, Claude gets better at understanding your specific project.

**Optional commands if you're curious:**
```bash
make init          # Tell Claude about your app (name, team, what data it handles)
```

After running `make init`, Claude knows things like "this is inventory-tracker for the dct-ops team, it handles internal data" — and adjusts its suggestions accordingly.

<br>

---

## All Commands

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
| `make fix` | Automatically fix lint and security issues |
| `make doctor` | Check if your security pipeline is healthy |
| `make scan` | Deep security scan |
| `make learn` | Take a 15-question security quiz (learn by doing) |
| `make dashboard` | Open an interactive visual of your security pipeline |
| `make init` | Personalize the project for your app and team |
| `make add-secret` | Safely store an API key (hidden input, goes to `.env`, never in code) |
| `make add-config` | Safely store a config file (`.json`, `.pem`, etc.) |
| `make docker` | Build a Docker image |

<br>

## Project Structure

```
.
├── CLAUDE.md                        # 15 security rules Claude follows automatically
├── .claude/
│   ├── commands/                    # /project:add-endpoint, /project:check, etc.
│   ├── rules/                      # Auto-apply by file type (security, testing, style, API)
│   ├── skills/                     # Security review skill (triggers on code changes)
│   ├── agents/                     # Security auditor + code reviewer agents
│   └── MEMORY.md                   # Project memory — Claude remembers across sessions
├── .github/
│   ├── workflows/ci.yml            # 6 automated checks on every PR
│   ├── pull_request_template.md    # Security checklist reviewers walk through
│   └── CODEOWNERS                  # Required reviewers
├── Makefile                        # All the commands above
├── setup.sh                        # One-command setup
├── scripts/
│   ├── doctor.sh                   # Health check
│   ├── add-secret.sh               # Safe secret storage
│   ├── security-quiz.sh            # Learn security by doing
│   └── git-hooks/                  # Pre-commit, post-checkout, pre-push
├── python/                         # Python starter (FastAPI + all middleware wired)
├── go/                             # Go starter (net/http + all middleware wired)
├── deploy/helm/                    # Kubernetes deployment (Helm chart)
├── docs/
│   ├── getting-started.md          # Step-by-step guide
│   ├── security-handbook.md        # Plain-English security guide (no jargon)
│   └── appsec-review-pack/        # Templates for security review
├── security-dashboard.html         # Interactive security pipeline visual
└── SECURITY.md                     # What to do if something goes wrong
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

**Do I need to know security to use this?**
No. That's the whole point. Claude follows the rules, hooks catch mistakes, GitHub Actions enforces everything. You focus on building.

**Can I use this without Claude Code?**
Yes. The hooks, GitHub Actions, and Makefile commands work on their own. You just won't get the AI commands and agents.

**What if something blocks my commit?**
Read the message — it tells you exactly what's wrong and how to fix it. Or run `make fix` and it tries to fix things automatically.

**What if I don't have Okta credentials?**
You don't need them for local development. The app runs in test mode by default. When you're ready to deploy, file an IT ticket — [instructions are in CLAUDE.md](CLAUDE.md#okta-app-registration--how-to-get-credentials).

**What languages does this support?**
Python (FastAPI) and Go (net/http). Setup asks which one you want. The other gets archived, not deleted — you can switch later.

**What's the security quiz?**
Run `make learn` and you get 15 multiple-choice questions about common security mistakes. It's a quick way to build intuition without reading a textbook.

---

<p align="center">
  <sub>Built for CoreWeave engineering teams. Questions? <code>#application-security</code> on Slack.</sub>
</p>
