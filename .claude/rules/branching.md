# Glob: **/*

## Branch Discipline

### Two Modes

**Trunk mode (default):** Everyone works on main. Pre-push checks ARE the quality gate.
No branches, no PRs, no merging. Best for small teams.

**Branch mode (opt-in):** Set `BRANCH_MODE=1` in `.env`. Direct pushes to main are blocked.
All changes go through feature branches + PRs. Best for larger teams or compliance.

### Trunk Mode (default)
- Work on main — the pre-push hook runs tests, security, room-lint, and agent review
- If checks pass, push goes through. If they fail, fix and retry.
- No branches to manage, no PRs to open, no merging

### Branch Mode (opt-in)
- Create branches: `make branch NAME=my-feature`
- If `AGENT_ROOM` is set, branches auto-prefix: `go/add-auth`, `python/fix-api`
- Open PRs: `make pr` — runs all checks, pushes, opens PR
- CI gates must pass before merge

### Starting an agent with a branch
```bash
make agent NAME=go                    # trunk mode — stays on main
make agent NAME=go BRANCH=add-login   # branch mode — creates go/add-login
```
