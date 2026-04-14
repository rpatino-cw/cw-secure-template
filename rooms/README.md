# Rooms — Multi-Agent Coordination

Multiple Claude Code agents work on the same codebase without conflicts.
Each agent owns a set of files. Nobody edits anyone else's files.
If you need a change in another room, you send a request.

## Quick Start

```bash
make rooms                    # one-time setup (auto-detects project structure)
make agent NAME=go-dev        # Terminal 1 — opens Claude as Go agent
make agent NAME=py-dev        # Terminal 2 — opens Claude as Python agent
make room-status              # check pending requests across all rooms
```

## How It Works

1. Each agent owns specific files/directories (defined in `rooms.json`)
2. `guard.sh` **hard-blocks** edits outside your room — the agent physically can't break the rule
3. If an agent needs a change in another room, it writes a request to that room's inbox
4. The owning agent checks its inbox, processes requests, and writes responses to its outbox

## Request Flow

```
Agent py-dev needs a new Go function
         │
         ▼
Writes:  rooms/go-dev/inbox/20260414-143022-from-py-dev.md
         "Add GetUserByEmail to go/models/user.go"
         │
         ▼
Agent go-dev checks inbox → processes request
         │
         ▼
Writes:  rooms/go-dev/outbox/20260414-143500-to-py-dev.md
         "Added GetUserByEmail at line 45.
          Import: models.GetUserByEmail(ctx, email)"
         │
         ▼
Agent py-dev checks outboxes for responses → continues work
```

## File Naming

Use timestamps, not sequential numbers (prevents collisions):

- Requests: `YYYYMMDD-HHMMSS-from-{your-room}.md`
- Responses: `YYYYMMDD-HHMMSS-to-{requester}.md`

## Rules

1. **Only edit files in your room.** Guard.sh enforces this — blocked edits explain what you own.
2. **Check your inbox every response.** Process requests one at a time, oldest first.
3. **Check outboxes for responses to you.** Look in `rooms/*/outbox/*-to-{your-room}.md`.
4. **Always respond.** Done, error, or blocked — never leave a request hanging.
5. **Shared files need approval.** Send a request to the approver room.
6. **No branches needed.** Everyone works on `main`. No merging.

## Customization

Edit `rooms.json` to change room assignments. Then re-run `make rooms`.
Delete `rooms.json` and run `make rooms` to auto-detect from scratch.
