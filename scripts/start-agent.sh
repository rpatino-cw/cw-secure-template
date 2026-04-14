#!/usr/bin/env bash
# start-agent.sh — Start a Claude Code session as a specific room agent
#
# Usage: make agent NAME=go-dev
#    or: bash scripts/start-agent.sh <room-name>
#
# This sets the AGENT_ROOM env var so Claude knows which room it owns,
# then launches Claude Code with the agent's identity pre-loaded.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOM_NAME="${1:-}"

if [ -z "$ROOM_NAME" ]; then
  echo ""
  echo "  Usage: make agent NAME=<room-name>"
  echo ""
  echo "  Available rooms:"
  for dir in "$REPO_ROOT"/rooms/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")
    echo "    - $name"
  done
  echo ""
  echo "  Example: make agent NAME=go-dev"
  echo ""
  exit 1
fi

AGENT_FILE="$REPO_ROOT/rooms/$ROOM_NAME/AGENT.md"

if [ ! -f "$AGENT_FILE" ]; then
  echo "  Error: Room '$ROOM_NAME' not found."
  echo "  Run 'make rooms' first, or check rooms.json."
  exit 1
fi

# Count pending inbox items
INBOX_COUNT=$(find "$REPO_ROOT/rooms/$ROOM_NAME/inbox" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "  Starting agent: $ROOM_NAME"
if [ "$INBOX_COUNT" -gt 0 ]; then
  echo "  Inbox: $INBOX_COUNT pending request(s)"
fi
echo ""

# Read the agent identity to pass as initial prompt context
AGENT_IDENTITY=$(cat "$AGENT_FILE")

# Launch Claude Code with room identity
export AGENT_ROOM="$ROOM_NAME"
exec claude --print-cost "$REPO_ROOT" -p "
You are agent **$ROOM_NAME**. Your identity and rules are below.

$AGENT_IDENTITY

---

Start by checking your inbox at rooms/$ROOM_NAME/inbox/ for pending requests.
Process them one at a time before doing any other work.
If the inbox is empty, say so and ask what I'd like you to work on.
"
