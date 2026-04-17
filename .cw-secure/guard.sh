#!/usr/bin/env bash
# PreToolUse guard — runs BEFORE Claude writes to any file.
# Claude Code pipes JSON on stdin with tool_name, file_path, content, etc.
# Exit 0 = allow, Exit 2 = block with message on stderr.
#
# This is a thin dispatcher. Actual checks live in scripts/guards/:
#   security.sh      — secrets, dangerous fns, protected files
#   architecture.sh  — stack lock, SQL in routes, auth, dependency direction
#   collaboration.sh — path traversal, write overwrite, teammate collision
#   rooms.sh         — room boundaries, dependency protection, rename inbox

set -euo pipefail

GUARD_DIR="$(cd "$(dirname "$0")" && pwd)/guards"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# ── Parse JSON input (shared by all guards) ──
INPUT="$(cat)"

read_field() {
  python3 -c "
import json, sys
data = json.loads(sys.argv[1])
tool_input = data.get('tool_input', {})
if sys.argv[2] == 'tool_name':
    print(data.get('tool_name', ''))
elif sys.argv[2] == 'file_path':
    print(tool_input.get('file_path', ''))
elif sys.argv[2] == 'content':
    print(tool_input.get('content', tool_input.get('new_string', '')))
" "$INPUT" "$1"
}

TOOL_NAME="$(read_field tool_name)"
FILE_PATH="$(read_field file_path)"
CONTENT="$(read_field content)"

OLD_STRING=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
print(data.get('tool_input', {}).get('old_string', ''))
" "$INPUT" 2>/dev/null || echo "")

# ── Config audit gate (must pass before any other guard) ──
source "$GUARD_DIR/config-audit.sh"

# ── Trust tier enforcement (before room checks) ──
source "$GUARD_DIR/trust.sh"

# ── Run all guards (source so they share variables) ──
source "$GUARD_DIR/collaboration.sh"
source "$GUARD_DIR/security.sh"
source "$GUARD_DIR/architecture.sh"
source "$GUARD_DIR/rooms.sh"
source "$GUARD_DIR/freeze.sh"
source "$GUARD_DIR/quality.sh"

# All checks passed
exit 0
