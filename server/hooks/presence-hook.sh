#!/usr/bin/env bash
# cw-secure-template · presence heartbeat hook
# Wired as a PostToolUse hook on Edit|Write in .claude/settings.json so every
# time an agent touches a file, the team sees what you're working on.
#
# Expected JSON on stdin (Claude Code's PostToolUse format):
#   { "tool_input": { "file_path": "..." }, ... }
#
# Env:
#   DASHBOARD_URL  — server address (default http://localhost:4000)
#   USER_ID        — who you are (default: $USER)
#   ROOM_ID        — override room; otherwise derived from rooms.json path prefix

set -eu

URL="${DASHBOARD_URL:-http://localhost:4000}"
USER_ID="${USER_ID:-${USER:-unknown}}"

INPUT="$(cat || echo '{}')"

# Extract file_path with jq if available, grep fallback otherwise
if command -v jq >/dev/null 2>&1; then
  FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')"
else
  FILE_PATH="$(echo "$INPUT" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
fi

[ -z "$FILE_PATH" ] && exit 0

# Derive room from path. Prefer explicit ROOM_ID; else match against rooms.json
# owner prefixes. Falls back to "unknown" — the server tolerates that.
ROOM="${ROOM_ID:-}"

if [ -z "$ROOM" ] && command -v python3 >/dev/null 2>&1; then
  # Find repo root from git, then parse rooms.json for path match
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "")"
  if [ -n "$REPO_ROOT" ] && [ -f "$REPO_ROOT/rooms.json" ]; then
    ROOM="$(python3 -c "
import json, os, sys
try:
    d = json.load(open('$REPO_ROOT/rooms.json'))
    rooms = d.get('rooms', {})
    fp = '$FILE_PATH'
    rel = os.path.relpath(fp, '$REPO_ROOT') if fp.startswith('$REPO_ROOT') else fp
    for name, info in rooms.items():
        for own in info.get('owns', []):
            if rel.startswith(own.rstrip('/')):
                print(name); sys.exit(0)
    print('unknown')
except Exception:
    print('unknown')
" 2>/dev/null || echo "unknown")"
  fi
fi

[ -z "$ROOM" ] && ROOM="unknown"

# POST heartbeat — best-effort, never blocks the tool call
curl -sS --max-time 2 \
  -X POST "$URL/api/presence" \
  -H "Content-Type: application/json" \
  -d "{\"user\":\"$USER_ID\",\"file\":\"$FILE_PATH\",\"room\":\"$ROOM\",\"state\":\"editing\"}" \
  >/dev/null 2>&1 || true

exit 0
