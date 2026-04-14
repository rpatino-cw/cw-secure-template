#!/usr/bin/env bash
# init-rooms.sh — Set up room-based multi-agent coordination
#
# Usage: make rooms
#    or: bash scripts/init-rooms.sh [rooms.json]
#
# Reads rooms.json and creates:
#   rooms/{name}/inbox/     — other agents drop requests here
#   rooms/{name}/outbox/    — this agent posts responses here
#   rooms/{name}/AGENT.md   — identity + rules for this agent
#   rooms/README.md         — usage guide
#
# Safe to re-run. Won't overwrite existing AGENT.md files.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-$REPO_ROOT/rooms.json}"
ROOMS_DIR="$REPO_ROOT/rooms"

# ─── Preflight ────────────────────────────────────────────

if [ ! -f "$CONFIG" ]; then
  echo "  Error: rooms.json not found at $CONFIG"
  echo "  Create one first — see rooms.json.example"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "  Error: jq is required. Install with: brew install jq"
  exit 1
fi

echo ""
echo "  Room Setup — Multi-Agent Coordination"
echo "  ──────────────────────────────────────"
echo ""

# ─── Create room directories ─────────────────────────────

ROOM_NAMES=$(jq -r '.rooms | keys[]' "$CONFIG")
ROOM_COUNT=$(echo "$ROOM_NAMES" | wc -l | tr -d ' ')

for ROOM in $ROOM_NAMES; do
  DESC=$(jq -r ".rooms[\"$ROOM\"].description" "$CONFIG")
  OWNS=$(jq -r ".rooms[\"$ROOM\"].owns | join(\", \")" "$CONFIG")

  # Create directories
  mkdir -p "$ROOMS_DIR/$ROOM/inbox"
  mkdir -p "$ROOMS_DIR/$ROOM/outbox"
  touch "$ROOMS_DIR/$ROOM/inbox/.gitkeep"
  touch "$ROOMS_DIR/$ROOM/outbox/.gitkeep"

  # Generate AGENT.md (skip if exists — don't overwrite customizations)
  AGENT_FILE="$ROOMS_DIR/$ROOM/AGENT.md"
  if [ ! -f "$AGENT_FILE" ]; then
    cat > "$AGENT_FILE" << AGENT
# Agent: $ROOM

> $DESC

## You Own

These are YOUR files. Only you edit them.

$(for path in $(jq -r ".rooms[\"$ROOM\"].owns[]" "$CONFIG"); do echo "- \`$path\`"; done)

## Rules

1. **Only edit files listed above.** If a file is not in your ownership list, you do NOT touch it.
2. **Check your inbox first.** At the start of every response, read all files in \`rooms/$ROOM/inbox/\`. Process them one at a time, oldest first.
3. **Respond to every request.** Write your response to \`rooms/$ROOM/outbox/\` using the same number as the request (e.g., inbox \`003-from-py-dev.md\` → outbox \`003-done.md\` or \`003-error.md\`).
4. **If you can't do it, say why.** Never silently skip a request. Write an error response with an explanation and a suggestion.
5. **If YOU need something from another room,** write a request to THEIR inbox: \`rooms/{other-room}/inbox/{number}-from-$ROOM.md\`. Then wait — check their outbox next cycle.
6. **Shared files** (listed in rooms.json under "shared") require a request to the approver room. Never edit shared files directly.

## Request Format (when you write TO another room's inbox)

\`\`\`markdown
---
from: $ROOM
priority: normal
---

[What you need, in plain English]
\`\`\`

## Response Format (when you write TO your outbox)

\`\`\`markdown
---
to: [requesting-agent]
status: done | error | blocked
files_changed: [list of files you modified]
---

[What you did, or why you couldn't]
\`\`\`
AGENT

    echo "  ✓ $ROOM — $DESC"
  else
    echo "  · $ROOM — already exists (skipped)"
  fi
done

# ─── Generate shared file list ────────────────────────────

SHARED_PATHS=$(jq -r '.shared.paths // [] | join(", ")' "$CONFIG")
SHARED_APPROVER=$(jq -r '.shared.approver // "none"' "$CONFIG")

# ─── Generate rooms/README.md ─────────────────────────────

cat > "$ROOMS_DIR/README.md" << 'HEADER'
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

HEADER

cat >> "$ROOMS_DIR/README.md" << EOF
## Rooms in This Project

| Room | Owns | Description |
|------|------|-------------|
$(for ROOM in $ROOM_NAMES; do
  DESC=$(jq -r ".rooms[\"$ROOM\"].description" "$CONFIG")
  OWNS=$(jq -r ".rooms[\"$ROOM\"].owns | join(\", \")" "$CONFIG")
  echo "| \`$ROOM\` | $OWNS | $DESC |"
done)

## Shared Files

These files have no single owner. To edit them, send a request to **$SHARED_APPROVER**.

$(for path in $(jq -r '.shared.paths[]' "$CONFIG"); do echo "- \`$path\`"; done)

## Request Flow

\`\`\`
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
\`\`\`

## Error Responses

If an agent can't fulfill a request, they write an error response:

\`\`\`markdown
---
to: py-dev
status: error
reason: architectural constraint
---

Can't expose raw DB connection to the API layer.
Suggestion: I'll create a GetUserByEmail(ctx, email) function
that returns a clean struct. You call that instead.

Waiting for approval before proceeding.
\`\`\`

## Rules

1. **Only edit files in your room.** Never touch another agent's files.
2. **Check your inbox every response.** Process requests one at a time.
3. **Always respond.** Done, error, or blocked — never leave a request hanging.
4. **Shared files need approval.** Send a request to \`$SHARED_APPROVER\`.
5. **No branches needed.** Everyone works on \`main\`. No merging.
EOF

# ─── Update .gitignore ────────────────────────────────────

GITIGNORE="$REPO_ROOT/.gitignore"
MARKER="# Room inbox/outbox (ephemeral agent messages)"

if ! grep -q "$MARKER" "$GITIGNORE" 2>/dev/null; then
  echo "" >> "$GITIGNORE"
  echo "$MARKER" >> "$GITIGNORE"
  echo "rooms/*/inbox/*.md" >> "$GITIGNORE"
  echo "rooms/*/outbox/*.md" >> "$GITIGNORE"
  echo "!rooms/*/inbox/.gitkeep" >> "$GITIGNORE"
  echo "!rooms/*/outbox/.gitkeep" >> "$GITIGNORE"
  echo "  ✓ Updated .gitignore"
fi

# ─── Summary ──────────────────────────────────────────────

echo ""
echo "  Done! $ROOM_COUNT rooms created in rooms/"
echo ""
echo "  Next steps:"
echo "    make agent NAME=go-dev     Start a Claude session as the Go agent"
echo "    make room-status           See pending requests across all rooms"
echo "    Edit rooms.json            Add/remove rooms for your project"
echo ""
