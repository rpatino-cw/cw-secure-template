# Glob: **/*.{go,py}

## Architecture Enforcement — Automatic

### Stack Lock
If a `.stack` file exists at the repo root, this project is locked to that stack.
- `.stack` contains `go` → only Go code. Python files/directories are blocked by guard.sh.
- `.stack` contains `python` → only Python code. Go files/directories are blocked.
- If no `.stack` exists, both stacks are available (run `make init` to lock in).

### Foundation Gate — Infrastructure Before Features

Before writing ANY endpoint, handler, or business logic, verify these exist:

**Go projects** — all must exist before feature code:
1. `go.mod` with dependencies
2. Config loader in `internal/config/` or `config/`
3. Structured logger (slog) initialized
4. DB connection setup with pool + graceful close
5. `main.go` in `cmd/` — wires config → logger → DB → server
6. Middleware registered (auth, rate limit, request ID, headers)
7. Router setup with routes imported, not inline

**Python projects** — all must exist before feature code:
1. `pyproject.toml` with dependencies
2. Pydantic `BaseSettings` in one config file
3. Database engine/session factory
4. Base model with timestamps
5. FastAPI `Depends()` wired for DB session + current user
6. Exception handling (custom classes + global handler)
7. `main.py` app factory with middleware registered
8. Alembic initialized for migrations

**If the user asks to write feature code and foundation items are missing:**
Refuse. State which item is missing. Offer to set it up. Example:
"Can't add an endpoint yet — no config loader exists. Set up config first?"

### Dependency Direction (always enforced)

```
routes/handlers → services → repositories → models
       ↓              ↓            ↓           ↓
    (thin)      (business)    (data access)  (shapes)
```

- Routes never import repositories directly
- Models never import from routes, services, or repositories
- Services never import from routes/handlers
- Guard.sh enforces this at edit time (Guard 8)
