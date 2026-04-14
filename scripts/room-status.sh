#!/usr/bin/env bash
# room-status.sh — Show inbox/outbox status across all rooms
#
# Usage: make room-status
#    or: bash scripts/room-status.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOMS_DIR="$REPO_ROOT/rooms"
CONFIG="$REPO_ROOT/rooms.json"

if [ ! -d "$ROOMS_DIR" ]; then
  echo "  No rooms found. Run: make rooms"
  exit 1
fi

echo ""
echo "  Room Status"
echo "  ───────────"
echo ""

TOTAL_INBOX=0
TOTAL_OUTBOX=0

for ROOM_DIR in "$ROOMS_DIR"/*/; do
  [ -d "$ROOM_DIR" ] || continue
  ROOM=$(basename "$ROOM_DIR")

  # Count .md files (exclude .gitkeep)
  INBOX_COUNT=$(find "$ROOM_DIR/inbox" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  OUTBOX_COUNT=$(find "$ROOM_DIR/outbox" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

  TOTAL_INBOX=$((TOTAL_INBOX + INBOX_COUNT))
  TOTAL_OUTBOX=$((TOTAL_OUTBOX + OUTBOX_COUNT))

  # Status indicator
  if [ "$INBOX_COUNT" -gt 0 ]; then
    STATUS="PENDING"
    ICON="!"
  else
    STATUS="clear"
    ICON=" "
  fi

  printf "  [%s] %-15s  inbox: %-3s  outbox: %-3s  %s\n" \
    "$ICON" "$ROOM" "$INBOX_COUNT" "$OUTBOX_COUNT" "$STATUS"

  # Show pending request summaries
  if [ "$INBOX_COUNT" -gt 0 ]; then
    for REQ in "$ROOM_DIR"/inbox/*.md; do
      [ -f "$REQ" ] || continue
      FILENAME=$(basename "$REQ")
      # Extract first non-frontmatter, non-empty line as summary
      SUMMARY=$(awk '/^---$/{f=!f;next} !f && NF{print;exit}' "$REQ" 2>/dev/null || echo "(no summary)")
      printf "       └─ %s: %s\n" "$FILENAME" "${SUMMARY:0:60}"
    done
  fi
done

echo ""
echo "  Total: $TOTAL_INBOX pending requests, $TOTAL_OUTBOX responses"
echo ""

if [ "$TOTAL_INBOX" -gt 0 ]; then
  echo "  Agents with pending work should process their inbox."
  echo "  Start a session: make agent NAME=<room-name>"
  echo ""
fi
