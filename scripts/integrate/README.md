# scripts/integrate/

Smart integration of the CW Secure framework into an **existing** app.
Complements `scripts/adopt.sh`, which handles the actual file writes.

## Three phases

```
SCAN → PLAN → APPLY
 ↓      ↓      ↓
scan.py plan.py apply.py   ← all read from one portability.yaml
```

| Phase | Reads | Writes | Purpose |
|---|---|---|---|
| **scan** | target repo | nothing | Detect stack, framework, existing CI, git state |
| **plan** | scan + portability.yaml | nothing | Build deterministic action list + wiring snippets |
| **apply** | plan | target repo | Execute — backup tag, working branch, rollback on error, manifest |

## Files

- `portability.yaml` — single source of truth: every template file's action (copy / merge / append / generate / skip), per-stack applicability, skip-if-detected rules, safety rails.
- `scan.py` — read-only detector. Multi-scope (handles monorepos). Outputs human summary or `--json`.
- `plan.py` — reads portability + runs scan → prints plan with wiring snippets. Or `--json` for machine consumption.
- `apply.py` — executes the plan. Creates backup tag + working branch. Rolls back on any error. Writes `.cw-integrate-manifest.json`. Idempotent — safe to re-run.

## Legacy: `scripts/adopt.sh`

`adopt.sh` is the previous hardcoded bash writer. It works, but its file list is frozen in shell. `apply.py` supersedes it — portability.yaml is the only source of truth. New work should use `make integrate`. `adopt.sh` stays available as `make adopt` for now.

## Usage

```bash
# Scan only — what's in the target
make integrate-scan TARGET=/path/to/app

# Plan — what would change (read-only diff)
make integrate-plan TARGET=/path/to/app

# Apply — writes files, backup tag, working branch, manifest
make integrate TARGET=/path/to/app

# Narrow to subpath (monorepos)
make integrate TARGET=/path/to/monorepo SCOPE=backend/

# Opt-in Node/Next integration
make integrate TARGET=/path/to/app INCLUDE_NODE=1

# Bypass safety gates (dirty tree, no git)
make integrate TARGET=/path/to/app FORCE=1
```

## Stack support

| Stack | Status | Detection signal | Framework recognition |
|---|---|---|---|
| **Go** | Primary | `go.mod` | gin, chi, gorilla, echo, fiber |
| **Python** | Primary | `pyproject.toml` / `requirements.txt` / `setup.py` | fastapi, flask, django, starlette, aiohttp |
| **Node / Next** | Opt-in (`--include-node`) | `package.json` with framework dep | next, express, fastify, koa, nestjs, hapi |

## What gets populated

For every stack-scoped file, these placeholders substitute at plan time:

| Placeholder | Source |
|---|---|
| `{{APP_NAME}}` | go.mod module basename / pyproject name / package name / dirname |
| `{{STACK}}` | `go` / `python` / `node` |
| `{{FRAMEWORK}}` | detected framework or `unknown` |
| `{{GO_MODULE}}` | full Go module path |
| `{{ENTRY_POINT}}` | `cmd/*/main.go` / `src/main.py` / `src/index.ts` (auto-detected) |
| `{{MIDDLEWARE_PATH}}` | existing `internal/middleware`, `src/middleware`, etc. — or inferred |
| `{{PY_IMPORT_PATH}}` | `MIDDLEWARE_PATH` with `/` → `.` for Python imports |
| `{{TEST_CMD}}`, `{{LINT_CMD}}` | stack-default |
| `{{AUTHOR}}` | `git config user.name` |

## Design notes

- **No AST surgery.** Middleware files are generated; wiring snippets are **printed**, not inserted into `main.go` / `main.py`. AST auto-wiring is too fragile to do silently.
- **Marker-based appends** keep `CLAUDE.md`, `.gitignore`, `.env.example`, `Makefile` idempotent — re-running replaces the marked section, doesn't duplicate it.
- **Skip-if-detected** means targets with existing `gosec` / `bandit` / `codeql` / `gitleaks` in CI won't get a conflicting `cw-security.yml` workflow.
- **Safety rails** (declared in `portability.yaml`, not yet enforced — `adopt.sh` will be upgraded to read them): require git repo, require clean tree, backup tag, working branch, rollback-on-error.
- **Manifest** (`.cw-integrate-manifest.json`) is the future basis for `integrate upgrade` and `integrate remove`. `adopt.sh` creates `.cw-secure/` today; the manifest layer is next.

## What's still TODO

1. `apply.py` — replace `adopt.sh`'s write loop with something that reads the plan directly (the portability YAML already contains every rule `adopt.sh` hardcodes). This removes the two-brains problem.
2. Safety rails enforcement — backup tag + working branch + rollback.
3. Manifest writer — enables clean uninstall and per-version upgrades.
4. Test fixtures under `scripts/integrate/tests/` — empty-fastapi, existing-claude-md, existing-precommit, go-monorepo, dirty-git, node-next.
