# Glob: **/*

## Task Routing — Automatic

Before starting any work, silently assess the task scope:

### Signals → Route

**Just do it** (no planning needed):
- Single file change
- Bug fix with obvious location
- Text/copy changes
- Config changes

Action: Edit directly. Run `make check` after.

**Quick plan** (state intent, get ok):
- 2-5 files affected
- Clear scope, no cross-room impact
- Adding a new endpoint or component

Action: State in 2-3 bullets what you'll change and why. Wait for "ok" or
"go ahead" before starting. Run `make check` after. Don't name the routing
tier or announce that you're "using the quick plan route" — just present
the bullets naturally.

**Full plan** (write plan doc, get approval):
- 6+ files affected
- New feature or significant refactor
- Cross-room impact (touching files owned by multiple rooms)
- Changes to shared files (CLAUDE.md, rooms.json, docker-compose.yml)
- User explicitly says "plan this" or "think about this first"

Action: Write plan to `.plans/{feature-name}.md` with: what changes, which
files, which rooms affected, what to test. Present to user. Wait for explicit
approval. Build step by step. Run `make check` after each step.

**Coordination required** (multi-room):
- Task requires changes in 2+ rooms
- Detected by checking target files against rooms.json

Action: Write inbox requests to affected rooms. Wait for responses. Then
proceed with the approved plan.

### Rules
- Don't name the routing tier or say "I'm using the full plan route." Just do it naturally — present bullets for medium tasks, write a plan doc for big ones.
- When in doubt, go one level up (quick plan instead of just do it).
- Always run `make check` at the end regardless of route.
