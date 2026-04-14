#!/usr/bin/env bash
# activity-log.sh — Auto-log agent activity and warn about overlaps
#
# PreToolUse hook for Edit|Write. Runs AFTER guard.sh (only if edit is allowed).
#
# 1. Appends this agent's edit intent to rooms/activity.md
# 2. Checks if another agent recently touched the same file
# 3. Outputs recent activity from OTHER agents on stdout (injected into Claude context)
#
# Never blocks (always exit 0). Skips silently if rooms aren't set up.

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
ACTIVITY_FILE="$REPO_ROOT/rooms/activity.md"
AGENT="${AGENT_ROOM:-}"

# Skip if rooms aren't set up or no agent identity
[ -d "$REPO_ROOT/rooms" ] || exit 0
[ -n "$AGENT" ] || exit 0

# Read the file path from stdin JSON
INPUT="$(cat)"
FILE_PATH=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
ti = data.get('tool_input', {})
print(ti.get('file_path', ''))
" "$INPUT" 2>/dev/null || echo "")

[ -n "$FILE_PATH" ] || exit 0

# Make path relative to repo
REL_PATH="${FILE_PATH#$REPO_ROOT/}"
REL_PATH="${REL_PATH#./}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
NOW_EPOCH=$(date +%s)

# ── Create activity file if missing ──
if [ ! -f "$ACTIVITY_FILE" ]; then
  cat > "$ACTIVITY_FILE" << 'HEADER'
# Activity Feed
# Auto-updated by agents. Do not edit manually.
# Format: TIMESTAMP | AGENT | FILE | EPOCH
HEADER
fi

# ── Append this agent's activity ──
echo "$TIMESTAMP | $AGENT | $REL_PATH | $NOW_EPOCH" >> "$ACTIVITY_FILE"

# ── Prune old entries (keep last 50 lines + header) ──
TOTAL=$(wc -l < "$ACTIVITY_FILE" | tr -d ' ')
if [ "$TOTAL" -gt 53 ]; then
  # Keep header (3 lines) + last 50 entries
  HEADER_LINES=$(head -3 "$ACTIVITY_FILE")
  TAIL_LINES=$(tail -50 "$ACTIVITY_FILE")
  printf '%s\n%s\n' "$HEADER_LINES" "$TAIL_LINES" > "$ACTIVITY_FILE"
fi

# ── Check for overlaps with OTHER agents (last 30 min) ──
CUTOFF=$((NOW_EPOCH - 1800))
WARNINGS=""
OTHER_ACTIVITY=""

while IFS='|' read -r ts agent file epoch; do
  # Trim whitespace
  agent=$(echo "$agent" | xargs)
  file=$(echo "$file" | xargs)
  epoch=$(echo "$epoch" | xargs)

  # Skip header lines, own entries, and old entries
  [[ "$ts" == "#"* ]] && continue
  [ "$agent" = "$AGENT" ] && continue
  [ -z "$epoch" ] && continue
  [ "$epoch" -lt "$CUTOFF" ] 2>/dev/null && continue

  # Calculate age
  AGE=$(( (NOW_EPOCH - epoch) / 60 ))
  if [ "$AGE" -lt 1 ]; then
    AGE_STR="just now"
  else
    AGE_STR="${AGE}m ago"
  fi

  OTHER_ACTIVITY="${OTHER_ACTIVITY}  ${agent} editing ${file} (${AGE_STR})\n"

  # Check if same file or same directory
  FILE_DIR=$(dirname "$REL_PATH")
  OTHER_DIR=$(dirname "$file")
  if [ "$REL_PATH" = "$file" ]; then
    WARNINGS="${WARNINGS}  WARNING: ${agent} is editing the SAME FILE: ${file} (${AGE_STR})\n"
  elif [ "$FILE_DIR" = "$OTHER_DIR" ]; then
    WARNINGS="${WARNINGS}  HEADS UP: ${agent} is editing in the same directory: ${file} (${AGE_STR})\n"
  fi
done < "$ACTIVITY_FILE"

# ── Output to stdout (injected into Claude's context) ──
if [ -n "$WARNINGS" ] || [ -n "$OTHER_ACTIVITY" ]; then
  echo "<agent-activity>"
  if [ -n "$WARNINGS" ]; then
    echo -e "$WARNINGS"
    echo "Consider sending a request to their inbox instead of editing directly."
  fi
  if [ -n "$OTHER_ACTIVITY" ]; then
    echo "Other agents active (last 30 min):"
    echo -e "$OTHER_ACTIVITY"
  fi
  echo "</agent-activity>"
fi

exit 0
