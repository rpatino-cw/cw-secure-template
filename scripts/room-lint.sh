#!/usr/bin/env bash
# room-lint.sh — Validate room configuration before push
#
# Checks:
#   1. rooms.json is valid JSON
#   2. Every owned path actually exists
#   3. No path is owned by two rooms
#   4. No owned path is also in shared.paths
#   5. Approver room exists
#   6. Every room has an AGENT.md
#
# Exit 0 = clean, Exit 1 = errors found

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/rooms.json"
ROOMS_DIR="$REPO_ROOT/rooms"

# Skip if rooms aren't set up
if [ ! -f "$CONFIG" ]; then
  exit 0
fi

ERRORS=0

err() {
  echo -e "  \033[0;31m[FAIL]\033[0m $1" >&2
  ((ERRORS++))
}

ok() {
  echo -e "  \033[0;32m[PASS]\033[0m $1"
}

# 1. Valid JSON
if ! python3 -c "import json; json.load(open('$CONFIG'))" 2>/dev/null; then
  err "rooms.json is not valid JSON"
  exit 1
fi
ok "rooms.json is valid JSON"

# Parse config once
ROOMS=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)

rooms = config.get('rooms', {})
shared = config.get('shared', {})

# 2. Check owned paths exist
for name, room in rooms.items():
    for path in room.get('owns', []):
        print(f'OWN|{name}|{path}')

# 3. Collect all paths for overlap check
all_paths = []
for name, room in rooms.items():
    for path in room.get('owns', []):
        all_paths.append((name, path))

# Check overlaps
for i, (name1, path1) in enumerate(all_paths):
    for name2, path2 in all_paths[i+1:]:
        p1 = path1.rstrip('/')
        p2 = path2.rstrip('/')
        if p1 == p2 or p1.startswith(p2 + '/') or p2.startswith(p1 + '/'):
            print(f'OVERLAP|{name1}:{path1}|{name2}:{path2}')

# 4. Check shared vs owned conflicts
shared_paths = shared.get('paths', [])
for name, room in rooms.items():
    for path in room.get('owns', []):
        p = path.rstrip('/')
        for sp in shared_paths:
            s = sp.rstrip('/')
            if p == s:
                print(f'CONFLICT|{name}|{path}|{sp}')

# 5. Check approver exists
approver = shared.get('approver', '')
if approver and approver not in rooms:
    print(f'NOAPPROVER|{approver}')

# 6. Room names
for name in rooms:
    print(f'ROOM|{name}')
" "$CONFIG" 2>/dev/null)

# 2. Check owned paths exist
while IFS='|' read -r type room path; do
  if [ "$type" = "OWN" ]; then
    target="$REPO_ROOT/$path"
    if [ ! -e "$target" ] && [ ! -e "${target%/}" ]; then
      err "Room '$room' owns '$path' but it doesn't exist"
    fi
  fi
done <<< "$ROOMS"

# Check for overlap/conflict/approver issues
HAS_OVERLAP=false
HAS_CONFLICT=false
while IFS='|' read -r type arg1 arg2; do
  case "$type" in
    OVERLAP)
      err "Ownership overlap: $arg1 and $arg2 share paths"
      HAS_OVERLAP=true
      ;;
    CONFLICT)
      err "Room '$arg1' owns '$arg2' but it's also in shared paths ('$(echo "$ROOMS" | grep "^CONFLICT|$arg1" | cut -d'|' -f4 | head -1)')"
      HAS_CONFLICT=true
      ;;
    NOAPPROVER)
      err "Shared approver room '$arg1' doesn't exist in rooms"
      ;;
  esac
done <<< "$ROOMS"

if [ "$HAS_OVERLAP" = false ]; then
  ok "No ownership overlaps"
fi
if [ "$HAS_CONFLICT" = false ]; then
  ok "No shared/owned conflicts"
fi

# 6. Check AGENT.md exists for each room
while IFS='|' read -r type name _; do
  if [ "$type" = "ROOM" ]; then
    if [ ! -f "$ROOMS_DIR/$name/AGENT.md" ]; then
      err "Room '$name' missing AGENT.md — run: make rooms"
    fi
  fi
done <<< "$ROOMS"

if [ -d "$ROOMS_DIR" ]; then
  ROOM_COUNT=$(find "$ROOMS_DIR" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
  AGENT_COUNT=$(find "$ROOMS_DIR" -name "AGENT.md" | wc -l | tr -d ' ')
  if [ "$ROOM_COUNT" -eq "$AGENT_COUNT" ]; then
    ok "All $ROOM_COUNT rooms have AGENT.md"
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo -e "  \033[0;31m$ERRORS room config issue(s) found. Fix before pushing.\033[0m"
  exit 1
fi

ok "Room configuration is clean"
exit 0
