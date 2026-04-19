#!/bin/bash
# cwt-gate.sh v2 — PreToolUse hook for CWT plan-gate
#
# Blocks Edit/Write/MultiEdit on files NOT listed in the active plan manifest.
#
# Semantics:
#   - No .cwt/ dir in project     → allow (CWT not installed)
#   - No manifest file            → allow (CWT installed but not initialized)
#   - Manifest.files[] is empty   → allow (gate idle, no active plan)
#   - Target is inside .cwt/**    → allow (CWT's own storage; bootstrap)
#   - Target is inside .cwt-build/** → allow (build artifacts; bootstrap)
#   - Target in manifest.files[]  → allow
#   - Target not in files[]       → BLOCK with stderr message
#   - Parse error                 → fail-open + warn on stderr

set -uo pipefail

INPUT=$(cat)

read -r TOOL FILE <<<"$(python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    tool = d.get('tool_name', '')
    fp = d.get('tool_input', {}).get('file_path', '')
    print(tool, fp)
except Exception:
    print('', '')
" <<<"$INPUT")"

case "$TOOL" in
    Edit|Write|MultiEdit) ;;
    *) exit 0 ;;
esac

# Walk up to find the project root (first parent containing .cwt/)
DIR="$(dirname "$FILE")"
while [[ "$DIR" != "/" && "$DIR" != "." && ! -d "$DIR/.cwt" ]]; do
    DIR="$(dirname "$DIR")"
done

[[ ! -d "$DIR/.cwt" ]] && exit 0

MANIFEST="$DIR/.cwt/manifest-approved.json"
[[ ! -f "$MANIFEST" ]] && exit 0

# Compute path relative to project root
REL="${FILE#$DIR/}"

# CWT's own storage is always editable — bootstrap without locking self out
case "$REL" in
    .cwt/*|.cwt-build/*) exit 0 ;;
esac

RESULT=$(python3 -c "
import json
try:
    m = json.load(open('$MANIFEST'))
    files = m.get('files', [])
    pid = m.get('plan_id', '(no plan id)')
    if not files:
        print('idle'); print(pid)
    elif '$REL' in files:
        print('allow'); print(pid)
    else:
        print('block'); print(pid)
except Exception as e:
    print('error'); print(str(e))
")

STATUS=$(echo "$RESULT" | sed -n '1p')
PLAN_ID=$(echo "$RESULT" | sed -n '2p')

case "$STATUS" in
    allow|idle) exit 0 ;;
    error)
        echo "CWT gate: manifest parse error, failing open ($PLAN_ID)" >&2
        exit 0
        ;;
esac

# Default: block
PORT_HINT=""
if [[ -f "$DIR/.cwt/port" ]]; then
    PORT_HINT="http://127.0.0.1:$(cat "$DIR/.cwt/port")"
else
    PORT_HINT="(server not running — run: python3 .cwt/server.py)"
fi

cat >&2 <<EOF
🛑 CWT PLAN GATE — edit blocked

File not in approved plan:   $REL
Current plan:                $PLAN_ID
Dashboard:                   $PORT_HINT

To proceed:
  1. Open the dashboard, approve a plan that includes this file, then retry.
  2. Or amend the pending plan to include "$REL".

To disable the gate temporarily:
  rm $MANIFEST
EOF

exit 2
