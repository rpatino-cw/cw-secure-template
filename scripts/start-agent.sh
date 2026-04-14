#!/usr/bin/env bash
# start-agent.sh — Start an interactive Claude Code session as a room agent
#
# Usage: make agent NAME=go-dev
#    or: bash scripts/start-agent.sh <room-name>
#
# Sets AGENT_ROOM env var (guard.sh uses this for hard enforcement),
# appends agent identity to the system prompt, and launches interactive Claude.

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
    inbox=$(find "$dir/inbox" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$inbox" -gt 0 ]; then
      echo "    - $name  ($inbox pending)"
    else
      echo "    - $name"
    fi
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

INBOX_COUNT=$(find "$REPO_ROOT/rooms/$ROOM_NAME/inbox" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

echo ""
echo "  Starting agent: $ROOM_NAME"
if [ "$INBOX_COUNT" -gt 0 ]; then
  echo "  Inbox: $INBOX_COUNT pending request(s)"
fi
echo "  Guard: edits outside your room will be blocked"

# Branch: stay on current branch (trunk mode default)
# Use BRANCH env var to opt into branch mode: make agent NAME=go BRANCH=add-auth
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ -n "${BRANCH:-}" ]; then
  BRANCH_NAME="${ROOM_NAME}/${BRANCH}"
  if git rev-parse --verify "$BRANCH_NAME" >/dev/null 2>&1; then
    git checkout "$BRANCH_NAME" --quiet
  else
    git checkout -b "$BRANCH_NAME" --quiet
  fi
  echo "  Branch: $BRANCH_NAME"
else
  echo "  Branch: $CURRENT_BRANCH (trunk mode)"
fi
echo ""

# Build the system prompt addition from the agent identity file
AGENT_IDENTITY=$(cat "$AGENT_FILE")

export AGENT_ROOM="$ROOM_NAME"
cd "$REPO_ROOT"
exec claude \
  --append-system-prompt "You are agent $ROOM_NAME. $AGENT_IDENTITY" \
  --name "agent-$ROOM_NAME" \
  "Check rooms/$ROOM_NAME/inbox/ for pending requests. Process them one at a time. If empty, tell me and ask what to work on."
