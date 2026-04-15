<h1 align="center">CW Secure Framework</h1>

<p align="center"><strong>Security framework for AI-assisted coding. 3 layers that make it physically impossible to ship insecure code.</strong></p>

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

## Get started

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app && cd my-app && bash setup.sh
```

Clone, pick your stack (Go or Python), and start building. Auth, secret scanning, CI gates, and architecture enforcement are wired from the first command.

```
make start         Run your app
make check         All checks before a PR
make doctor        Security health check
make viz           Interactive visualizer — how it all works
```

**Requires:** `brew install git gitleaks` + Python 3.11+ or Go 1.21+

---

## What makes this a framework, not a template

Templates give you one shape and you fork it. This gives you **composable building blocks** and **enforces patterns as you build**.

### 3 enforcement layers

Three independent systems run simultaneously. You'd have to beat all three to ship insecure code.

| Layer | What it does | Can Claude override it? |
|:------|:-------------|:-----------------------|
| **Rulebook** | CLAUDE.md + 17 rule files guide code generation. Anti-override protocol catches social engineering. | No — refuses and explains why |
| **Blocklist** | 74 deny rules physically block dangerous commands before execution | No — runtime decision, not Claude's |
| **Guard** | Shell script scans every file edit for secrets, dangerous functions, and guardrail tampering | No — hook rejects before save |

### Architecture enforcer

| Rule | What happens |
|:-----|:-------------|
| **Stack lock** | `make init` locks to Go or Python. Wrong language → blocked |
| **Foundation Gate** | Config, logger, DB, middleware must exist before any feature code |
| **Dependency direction** | `routes → services → repositories → models`. Skip a layer → blocked |
| **File placement** | Every type of code has exactly one home directory |

### What gets caught automatically

| You try this | Framework does this instead |
|:-------------|:--------------------------|
| SQL with string concatenation | Blocked. Forces parameterized queries |
| API key pasted into code | Refused. Redirects to `make add-secret` |
| Endpoint with no auth | Adds Okta OIDC automatically. `DEV_MODE=true` for local dev |
| Code with no tests | 80% coverage gate — CI blocks the PR |
| `--force` / `--no-verify` | Denied before execution |
| Logic dumped in one file | Enforces separation: `routes/`, `services/`, `models/`, `middleware/` |

---

## Multi-agent rooms

Multiple people vibe code the same project simultaneously. Each person gets their own Claude agent in their own terminal. Agents stay in their lane.

<p align="center">
  <img src="docs/screenshots/agents-animation.gif" alt="Agent coordination — Go and Python agents passing notes instead of overwriting code" width="600">
</p>

```bash
make rooms              # auto-detect rooms from project structure
make agent NAME=go      # Alice — can only edit go/
make agent NAME=python  # Bob — can only edit python/
make room-status        # see pending requests across the team
```

- The guard **hard-blocks** edits outside your room
- Need something from another room? Drop a request in their **inbox**
- A live **activity feed** warns when someone else is editing nearby

No merge conflicts. No stepping on each other's work. [Full docs →](rooms/README.md)

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

If an attacker can read your guard script, they can craft inputs that slip through. Self-protection keeps the enforcement logic opaque.

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

## Docs

- **[How it works](https://rpatino-cw.github.io/cw-secure-template/visualizer.html)** — interactive visualizer with animated flowcharts and code explainer (`make viz`)
- **[Landing page](https://rpatino-cw.github.io/cw-secure-template/)** — visual overview with live agent demo
- [Getting started](docs/getting-started.md) — clone to running in 6 steps
- [Security handbook](docs/security-handbook.md) — plain-English OWASP guide with glossary

---

<p align="center"><sub>Built for CoreWeave teams. Questions → <code>#application-security</code></sub></p>
