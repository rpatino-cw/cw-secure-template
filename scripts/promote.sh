#!/usr/bin/env bash
# promote.sh — Promote or demote a team member
#
# Usage: make promote NAME=alice TIER=builder
#        make demote  NAME=alice TIER=starter
#    or: bash scripts/promote.sh <name> <tier>

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEAM_CONFIG="$REPO_ROOT/team.json"

NAME="${1:-}"
TIER="${2:-}"

if [[ -z "$NAME" || -z "$TIER" ]]; then
  echo ""
  echo "  Usage: make promote NAME=<username> TIER=<starter|builder|lead>"
  echo ""
  exit 1
fi

if [[ "$TIER" != "starter" && "$TIER" != "builder" && "$TIER" != "lead" ]]; then
  echo "  Error: TIER must be starter, builder, or lead (got '$TIER')"
  exit 1
fi

if [[ ! -f "$TEAM_CONFIG" ]]; then
  echo "  Error: No team.json found. Run 'make join' first."
  exit 1
fi

# Check member exists
CURRENT=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    team = json.load(f)
member = team.get('members', {}).get(sys.argv[2])
if member:
    print(member['tier'])
else:
    print('')
" "$TEAM_CONFIG" "$NAME" 2>/dev/null || echo "")

if [[ -z "$CURRENT" ]]; then
  echo "  Error: '$NAME' not in team.json. Run 'make join' to add them first."
  exit 1
fi

if [[ "$CURRENT" == "$TIER" ]]; then
  echo "  $NAME is already $TIER."
  exit 0
fi

# Update tier
python3 -c "
import json, sys
with open(sys.argv[1], 'r') as f:
    team = json.load(f)
team['members'][sys.argv[2]]['tier'] = sys.argv[3]
with open(sys.argv[1], 'w') as f:
    json.dump(team, f, indent=2)
    f.write('\n')
" "$TEAM_CONFIG" "$NAME" "$TIER"

echo ""
echo "  $NAME: $CURRENT → $TIER"
echo ""
