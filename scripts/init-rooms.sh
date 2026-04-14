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
  echo "  No rooms.json found — auto-detecting project structure..."
  echo ""
  python3 "$REPO_ROOT/scripts/auto-rooms.py" --write
  if [ ! -f "$CONFIG" ]; then
    echo "  Auto-detection failed. Create rooms.json manually."
    exit 1
  fi
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
2. **Check your inbox first.** At the start of every response, read \`rooms/$ROOM/inbox/\`. Process requests one at a time, oldest first.
3. **Check for responses to you.** Also check \`rooms/*/outbox/*-to-$ROOM.md\` for responses from other agents.
4. **Respond to every request.** Write your response to \`rooms/$ROOM/outbox/\`. If you can't do it, say why — never silently skip.
5. **If YOU need something from another room,** write a request to their inbox. Then wait — check their outbox next cycle.
6. **Shared files** require a request to the approver room. Never edit shared files directly.

## File Naming — Use Timestamps

Requests: \`rooms/{target}/inbox/YYYYMMDD-HHMMSS-from-$ROOM.md\`
Responses: \`rooms/$ROOM/outbox/YYYYMMDD-HHMMSS-to-{requester}.md\`

Example request:
\`\`\`markdown
---
from: $ROOM
priority: normal
---
[What you need, in plain English]
\`\`\`

Example response:
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
\`\`\`

## File Naming

Use timestamps (prevents collisions between agents):
- Requests: \`YYYYMMDD-HHMMSS-from-{your-room}.md\`
- Responses: \`YYYYMMDD-HHMMSS-to-{requester}.md\`

## Rules

1. **Only edit files in your room.** Guard.sh enforces this — blocked edits explain what you own.
2. **Check your inbox every response.** Process requests one at a time, oldest first.
3. **Check outboxes for responses to you.** Look in \`rooms/*/outbox/*-to-{your-room}.md\`.
4. **Always respond.** Done, error, or blocked — never leave a request hanging.
5. **Shared files need approval.** Send a request to \`$SHARED_APPROVER\`.
6. **No branches needed.** Everyone works on \`main\`. No merging.
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
