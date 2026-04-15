# Architecture

Visual guide to how the framework enforces structure, security, and collaboration.

---

## The 3 enforcement layers

```
  ┌───────────────────────────────────────────────────────┐
  │                    YOUR PROMPT                         │
  │          "Add a users endpoint with no auth"           │
  └───────────────────┬───────────────────────────────────┘
                      │
                      ▼
  ┌─────────────────────────────────────────────────┐
  │  LAYER 1 — RULEBOOK                             │
  │  CLAUDE.md + 17 rule files                      │
  │                                                 │
  │  Claude reads the rules and generates code      │
  │  that follows them. Anti-override protocol      │
  │  catches social engineering attempts.            │
  │                                                 │
  │  "No auth" → Claude adds Okta OIDC anyway.     │
  └───────────────────┬─────────────────────────────┘
                      │
                      ▼
  ┌─────────────────────────────────────────────────┐
  │  LAYER 2 — BLOCKLIST                            │
  │  settings.json → 74 deny rules                  │
  │                                                 │
  │  The Claude Code RUNTIME blocks dangerous       │
  │  commands BEFORE execution. Claude never         │
  │  sees the result — the command is rejected.      │
  │                                                 │
  │  git push --force → DENIED (runtime decision)   │
  └───────────────────┬─────────────────────────────┘
                      │
                      ▼
  ┌─────────────────────────────────────────────────┐
  │  LAYER 3 — GUARD                                │
  │  scripts/guard.sh → pre-commit hook              │
  │                                                 │
  │  Shell script scans EVERY file edit for:         │
  │  - Secrets / API keys in source code             │
  │  - Dangerous functions (eval, exec, pickle)      │
  │  - Guardrail file tampering                      │
  │  - Full-file overwrites                          │
  │                                                 │
  │  Fires BEFORE the file is saved.                 │
  └───────────────────┬─────────────────────────────┘
                      │
                      ▼
  ┌─────────────────────────────────────────────────┐
  │              CLEAN, SECURE CODE                  │
  │  Auth ✓  Secrets safe ✓  Tests ✓  Architecture ✓ │
  └─────────────────────────────────────────────────┘
```

---

## Dependency direction

Code flows one way. Skip a layer and the guard blocks it.

```
  ┌──────────────────────────────────────────────────────────┐
  │                                                          │
  │   routes/handlers        THIN — 10-20 lines max          │
  │   Parse request → call service → return response         │
  │          │                                               │
  │          │  routes/ imports from services/                │
  │          ▼                                               │
  │   services/              THE BRAIN — business logic      │
  │   Rules, validation, orchestration                       │
  │          │                                               │
  │          │  services/ imports from repositories/          │
  │          ▼                                               │
  │   repositories/          DATA ACCESS — queries only      │
  │   SQL, connections, pagination                           │
  │          │                                               │
  │          │  repositories/ imports from models/            │
  │          ▼                                               │
  │   models/                SHAPES — zero dependencies      │
  │   Pydantic models, SQLAlchemy tables, Go structs         │
  │                                                          │
  └──────────────────────────────────────────────────────────┘

  BLOCKED:
  ✗ routes/ importing from repositories/    (skip the service layer)
  ✗ models/ importing from services/        (wrong direction)
  ✗ services/ importing from routes/        (circular dependency)
```

---

## Foundation Gate

Infrastructure must exist BEFORE feature code. Claude refuses to write endpoints until the foundation is in place.

```
  REQUIRED (in order):
  ┌──────────────────────────────────────────────────────────┐
  │  [1] Config loader         reads env, fails fast         │
  │  [2] Logger initialized    structured JSON output        │
  │  [3] DB connection          pool + graceful close        │
  │  [4] Middleware registered  auth, rate limit, headers    │
  │  [5] Router setup           routes imported, not inline  │
  └──────────────────────────────────────────────────────────┘
           │
           │  All 5 present?
           ▼
  ┌──────────────────────────────────────────────────────────┐
  │  NOW you can write feature code:                         │
  │  endpoints, services, models, tests                      │
  └──────────────────────────────────────────────────────────┘

  Missing #3 (DB)?
  → Claude says: "Can't add an endpoint yet — no DB connection exists. Set it up first?"
```

---

## Directory ownership

Every file type has one home. The guard enforces placement.

```
  my-app/
  ├── main.go / main.py          Entry point — startup wiring ONLY (< 50 lines)
  ├── config/                     Environment reads + constants
  ├── middleware/                  Auth, rate limiting, request ID, headers
  ├── routes/                     HTTP handlers (thin — call services)
  ├── services/                   Business logic (the brain)
  ├── repositories/               Database queries (data access)
  ├── models/                     Data shapes (depends on nothing)
  ├── utils/                      Pure utility functions (no side effects)
  ├── migrations/                 Database schema changes (numbered)
  └── tests/                      Test files (80% coverage minimum)
```

---

## Multi-agent room coordination

```
  ┌─────────────────────────────────────────────────────────────┐
  │                        rooms.json                           │
  │                                                             │
  │  go-dev      → owns go/                                     │
  │  py-dev      → owns python/                                 │
  │  security    → owns guard.sh, hooks, rules                  │
  │  devex       → owns Makefile, docs/, scripts/               │
  │  ci          → owns .github/                                │
  │                                                             │
  │  shared files (CLAUDE.md, .env.example) → need approval     │
  └─────────────────────────────────────────────────────────────┘

  Request flow:

  py-dev needs a Go function
       │
       ▼
  Writes: rooms/go-dev/inbox/20260414-143022-from-py-dev.md
          "Add GetUserByEmail to go/models/user.go"
       │
       ▼
  go-dev agent checks inbox → implements the function
       │
       ▼
  Writes: rooms/go-dev/outbox/20260414-143500-to-py-dev.md
          "Done. Import: models.GetUserByEmail(ctx, email)"
       │
       ▼
  py-dev picks up the response → continues building

  HARD RULE: guard.sh blocks edits outside your room.
  No exceptions. No overrides. Not a suggestion — a wall.
```

---

## What gets blocked vs. allowed

| Action | Allowed? | Why |
|:-------|:---------|:----|
| Write parameterized SQL query | Yes | Safe database access pattern |
| Write `f"SELECT * FROM users WHERE id = {id}"` | **No** | SQL injection via string concatenation |
| Use `os.environ["API_KEY"]` | Yes | Reads secret from environment |
| Paste API key in source file | **No** | Redirected to `make add-secret` |
| Add endpoint with auth middleware | Yes | Follows security rules |
| Add endpoint with no auth | **No** | Auth is required on all endpoints except /healthz |
| Import service from route handler | Yes | Correct dependency direction |
| Import repository from route handler | **No** | Skips the service layer |
| `git commit` (with hooks) | Yes | Guard runs before save |
| `git commit --no-verify` | **No** | Blocked by runtime deny list |
| `git push` to feature branch | Yes | Normal workflow |
| `git push --force` to main | **No** | Blocked by runtime deny list |
| Edit file in your room | Yes | You own it |
| Edit file in another room | **No** | Guard blocks cross-room edits |
| Read guard.sh source | **No** | Self-protection deny rules |
| Run `make doctor` | Yes | Health check with fix guidance |
