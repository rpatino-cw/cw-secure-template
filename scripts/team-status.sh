#!/usr/bin/env bash
# team-status.sh — Show team roster with rooms and tiers
#
# Usage: make team

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_CONFIG="$REPO_ROOT/team.json"

if [[ ! -f "$TEAM_CONFIG" ]]; then
  echo ""
  echo "  No team yet. Run 'make join' to add the first member."
  echo ""
  exit 0
fi

MEMBER_COUNT=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    team = json.load(f)
print(len(team.get('members', {})))
" "$TEAM_CONFIG" 2>/dev/null || echo "0")

if [[ "$MEMBER_COUNT" == "0" ]]; then
  echo ""
  echo "  No team members yet. Run 'make join' to add the first member."
  echo ""
  exit 0
fi

echo ""
echo "  Team Roster"
echo "  ───────────"
echo ""

python3 -c "
import json, sys

COLORS = {
    'starter': '\033[33m',  # yellow
    'builder': '\033[36m',  # cyan
    'lead':    '\033[35m',  # magenta
}
NC = '\033[0m'

with open(sys.argv[1]) as f:
    team = json.load(f)

for name, info in sorted(team.get('members', {}).items()):
    tier = info.get('tier', '?')
    room = info.get('room', '?')
    joined = info.get('joined', '?')
    color = COLORS.get(tier, '')
    print(f'    {name:<16} {color}{tier:<10}{NC} {room:<16} joined {joined}')
" "$TEAM_CONFIG"

echo ""
echo "  Promote: make promote NAME=<user> TIER=<builder|lead>"
echo "  Add:     make join"
echo ""
