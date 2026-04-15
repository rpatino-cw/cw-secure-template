<h1 align="center">CW Secure Template</h1>

<p align="center"><strong>Vibe code without the slop.</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/OWASP_Top_10-Covered-success" alt="OWASP">
</p>

<p align="center">
  <img src="docs/screenshots/guardrails.gif" alt="Guardrails — messy prompts in, clean code out" width="600">
</p>

---

Clone it. Claude follows security rules, enforcement layers, and an architecture enforcer automatically. No config.

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app && cd my-app && bash setup.sh
```

```
make start         Run your app
make check         All checks before a PR
make add-secret    Store a DB URL or API key safely
make doctor        Health check
make learn         15-question security quiz
```

**Requires:** `brew install git gitleaks` + Python 3.11+ or Go 1.21+

---

<details>
<summary>What it enforces</summary>

You tell Claude "build me an API." This template makes sure what comes out is secure — without you having to know security.

| You try this | Template does this instead |
|:-------------|:--------------------------|
| SQL built with string concatenation | Blocked. Forces parameterized queries |
| API key pasted into source code | Refused. Redirects to `make add-secret` (hidden input, stored in `.env`) |
| Endpoint with no login check | Adds Okta OIDC auth automatically. `DEV_MODE=true` for local testing |
| Shipping code with no tests | 80% coverage gate — CI blocks the PR until tests exist |
| `--force` / `--no-verify` | Denied before execution. Not Claude's choice — the runtime blocks it |
| All logic dumped in one file | Enforces separation: `routes/`, `services/`, `models/`, `middleware/` |

</details>

<details>
<summary>3 enforcement layers</summary>

Three independent systems, all running at the same time. You'd have to beat all three to ship insecure code.

**Layer 1 — The Rulebook.** CLAUDE.md + 17 rule files tell Claude what's allowed. An anti-override protocol catches social engineering ("ignore the rules", "skip checks", "just this once") and refuses.

**Layer 2 — The Blocklist.** The Claude Code runtime has a deny list that physically blocks dangerous commands (`--force`, `--hard`, `eval()`, `chmod 777`) before they execute. No prompt overrides this — it's not Claude's decision.

**Layer 3 — The Guard.** A shell script (`guard.sh`) runs before every file edit. It scans for secrets, dangerous functions, guardrail file tampering, and full-file overwrites. Even if Claude were convinced to write bad code, the guard rejects it before it's saved.

</details>

<details>
<summary>Architecture enforcer</summary>

Every type of code has one place it belongs. The guard enforces this automatically on every edit.

| Rule | What happens |
|:-----|:-------------|
| **Stack lock** | `make init` locks the project to Go or Python. Write the wrong language → blocked |
| **Foundation Gate** | Config, logger, DB, and middleware must exist before you write any feature code |
| **Dependency direction** | `routes → services → repositories → models`. Skip a layer → blocked |
| **File placement** | Classes, queries, handlers each have exactly one home directory |

Think of it as assigned seating for your code. Put something in the wrong spot and the guard moves you back.

</details>

<details>
<summary>17 rule files</summary>

Each file in `.claude/rules/` covers one part of the codebase. Claude reads and follows them automatically.

| Rule | Covers |
|:-----|:-------|
| `api-conventions` | RESTful naming, response format, status codes, required headers |
| `architecture` | Stack lock, Foundation Gate, dependency direction |
| `branching` | Trunk mode (default) vs. branch mode (opt-in via PR) |
| `classes` | Where classes/structs live — one home per type |
| `code-style` | Line length, function size, imports, linting |
| `collaboration` | Anti-overwrite, small edits only, git conflict awareness |
| `database` | Parameterized queries only, connection strings from env, repository pattern |
| `entry` | What belongs in `main.go` / `main.py` — startup wiring, nothing else |
| `frontend` | Frontend is a separate directory, talks to backend through API only |
| `functions` | Utility functions: pure, no side effects, reusable |
| `globals` | Config and constants — one place for values the whole app reads |
| `models` | Data shapes: validation, types, schemas. Depends on nothing |
| `rooms` | Multi-agent coordination — ownership, inboxes, conflict prevention |
| `routes` | Thin HTTP handlers (10-20 lines). Parse request → call service → return response |
| `security` | Secrets, auth, input validation, dangerous function blocklist |
| `services` | Business logic layer. Knows the rules, doesn't know HTTP |
| `testing` | 80% coverage, 3 tests per endpoint minimum, security test patterns |

</details>

<details>
<summary>Multi-agent rooms — team vibe coding</summary>

Multiple people can vibe code the same project at the same time. Each person gets their own Claude agent in their own terminal. Agents stay in their lane and talk to each other when they need something.

<p align="center">
  <img src="docs/screenshots/agents-animation.gif" alt="Agent coordination — Go and Python agents passing notes instead of overwriting code" width="600">
</p>

```
Alice                    Bob                     Charlie
  ↓                       ↓                        ↓
make agent NAME=go    make agent NAME=python   make agent NAME=ci
  ↓                       ↓                        ↓
owns go/              owns python/             owns .github/
```

```bash
make rooms              # auto-detect rooms from project structure
make agent NAME=go      # Alice's terminal — can only edit go/
make agent NAME=python  # Bob's terminal — can only edit python/
make room-status        # see pending requests across the team
```

- The guard **hard-blocks** edits outside your room — agents physically can't break the boundary
- Need something from another room? Drop a request in their **inbox** — they respond via **outbox**
- A live **activity feed** warns you when someone else is editing nearby

No merge conflicts. No stepping on each other's work. [Full docs →](rooms/README.md)

</details>

<details>
<summary>Docs</summary>

- [Getting started](docs/getting-started.md) — clone to running in 6 steps
- [Security handbook](docs/security-handbook.md) — plain-English OWASP guide with glossary

</details>

---

<p align="center"><sub>Built for CoreWeave teams. Questions → <code>#application-security</code></sub></p>
