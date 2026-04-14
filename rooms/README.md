# Rooms — Multi-Agent Coordination

This project uses **room-based coordination** so multiple Claude Code agents
can work on the same codebase without overwriting each other's code.

## How It Works

```
Each agent owns a "room" (a set of files/folders).
Nobody edits files in anyone else's room.
If you need a change in another room, you send a request.
There is nothing to merge. There are no conflicts.
```

## Quick Start

```bash
# 1. Set up rooms (first time only)
make rooms

# 2. Start an agent session
make agent NAME=go-dev    # opens Claude as the Go agent
make agent NAME=py-dev    # opens Claude as the Python agent

# 3. Check room status (pending requests, responses)
make room-status
```

## Rooms in This Project

| Room | Owns | Description |
|------|------|-------------|
| `ci` | .github/ | GitHub Actions, branch protection, CODEOWNERS, PR template |
| `devex` | scripts/doctor.sh, scripts/security-fix.sh, scripts/security-quiz.sh, scripts/add-secret.sh, scripts/add-config.sh, scripts/init-project.sh, setup.sh, Makefile, docs/, security-dashboard.html | Setup, docs, Makefile, health checks, onboarding scripts |
| `go-dev` | go/ | Go application — endpoints, middleware, models, migrations |
| `py-dev` | python/ | Python application — FastAPI, middleware, models, migrations |
| `security` | scripts/guard.sh, scripts/guard-bash.sh, scripts/git-hooks/, .pre-commit-config.yaml, SECURITY.md | Guard hooks, security rules, incident response, pre-commit |

## Shared Files

These files have no single owner. To edit them, send a request to **security**.

- `CLAUDE.md`
- `.claude/rules/`
- `.claude/settings.json`
- `.env.example`
- `.gitignore`
- `README.md`
- `docker-compose.yml`

## Request Flow

```
Agent py-dev needs a new Go function
         │
         ▼
Writes:  rooms/go-dev/inbox/001-from-py-dev.md
         "Add GetUserByEmail to go/models/user.go"
         │
         ▼
Agent go-dev checks inbox → processes request
         │
         ▼
Writes:  rooms/go-dev/outbox/001-done.md
         "Added GetUserByEmail at line 45.
          Import: models.GetUserByEmail(ctx, email)"
         │
         ▼
Agent py-dev reads the response → continues work
```

## Error Responses

If an agent can't fulfill a request, they write an error response:

```markdown
---
to: py-dev
status: error
reason: architectural constraint
---

Can't expose raw DB connection to the API layer.
Suggestion: I'll create a GetUserByEmail(ctx, email) function
that returns a clean struct. You call that instead.

Waiting for approval before proceeding.
```

## Rules

1. **Only edit files in your room.** Never touch another agent's files.
2. **Check your inbox every response.** Process requests one at a time.
3. **Always respond.** Done, error, or blocked — never leave a request hanging.
4. **Shared files need approval.** Send a request to `security`.
5. **No branches needed.** Everyone works on `main`. No merging.
