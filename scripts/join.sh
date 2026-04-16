#!/usr/bin/env bash
# join.sh — Interactive role self-selection for new team members
#
# Usage: make join
#    or: bash scripts/join.sh [USERNAME]
#
# Reads rooms.json, presents a menu, writes to team.json.
# First member automatically becomes lead.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOMS_CONFIG="$REPO_ROOT/rooms.json"
TEAM_CONFIG="$REPO_ROOT/team.json"

# Get username
USERNAME="${1:-${VIBE_USER:-${USER:-$(whoami)}}}"

# Check rooms.json exists
if [[ ! -f "$ROOMS_CONFIG" ]]; then
  echo ""
  echo "  No rooms.json found. Run 'make rooms' first to set up room assignments."
  echo ""
  exit 1
fi

# Check if user already in team
if [[ -f "$TEAM_CONFIG" ]]; then
  EXISTING=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    team = json.load(f)
member = team.get('members', {}).get(sys.argv[2])
if member:
    print(f\"{member['room']} ({member['tier']})\")
" "$TEAM_CONFIG" "$USERNAME" 2>/dev/null || echo "")

  if [[ -n "$EXISTING" ]]; then
    echo ""
    echo "  You're already on the team: $USERNAME → $EXISTING"
    echo ""
    read -rp "  Switch rooms? (y/n): " SWITCH
    if [[ "$SWITCH" != "y" && "$SWITCH" != "Y" ]]; then
      echo "  Keeping current assignment."
      exit 0
    fi
  fi
fi

# Read project name from directory
PROJECT_NAME=$(basename "$REPO_ROOT")

# Build menu from rooms.json
echo ""
echo "  Welcome to $PROJECT_NAME."
echo ""
echo "  What are you working on?"

ROOMS=()
while IFS= read -r line; do
  ROOMS+=("$line")
done < <(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
rooms = config.get('rooms', {})
for name, info in rooms.items():
    desc = info.get('description', name)
    if len(desc) > 60:
        desc = desc[:57] + '...'
    print(f'{name}|{desc}')
" "$ROOMS_CONFIG" 2>/dev/null)

for i in "${!ROOMS[@]}"; do
  NAME=$(echo "${ROOMS[$i]}" | cut -d'|' -f1)
  DESC=$(echo "${ROOMS[$i]}" | cut -d'|' -f2-)
  printf "    %d. %s — %s\n" "$((i+1))" "$NAME" "$DESC"
done

echo ""
read -rp "  Pick a number: " CHOICE

# Validate choice
if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || (( CHOICE < 1 || CHOICE > ${#ROOMS[@]} )); then
  echo "  Invalid choice. Run 'make join' to try again."
  exit 1
fi

SELECTED_ROOM=$(echo "${ROOMS[$((CHOICE-1))]}" | cut -d'|' -f1)

# Determine tier — first member becomes lead
TIER="starter"
if [[ ! -f "$TEAM_CONFIG" ]] || [[ $(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    team = json.load(f)
print(len(team.get('members', {})))
" "$TEAM_CONFIG" 2>/dev/null) == "0" ]]; then
  TIER="lead"
fi

# Initialize team.json if needed
if [[ ! -f "$TEAM_CONFIG" ]]; then
  echo '{"version": 1, "members": {}}' > "$TEAM_CONFIG"
fi

# Write member to team.json
TODAY=$(date +%Y-%m-%d)
python3 -c "
import json, sys
with open(sys.argv[1], 'r') as f:
    team = json.load(f)
team.setdefault('members', {})[sys.argv[2]] = {
    'room': sys.argv[3],
    'tier': sys.argv[4],
    'joined': sys.argv[5]
}
with open(sys.argv[1], 'w') as f:
    json.dump(team, f, indent=2)
    f.write('\n')
" "$TEAM_CONFIG" "$USERNAME" "$SELECTED_ROOM" "$TIER" "$TODAY"

# Get room's owned paths
OWNED=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
room = config.get('rooms', {}).get(sys.argv[2], {})
print(', '.join(room.get('owns', ['(none)'])))
" "$ROOMS_CONFIG" "$SELECTED_ROOM" 2>/dev/null || echo "(unknown)")

echo ""
echo "  You're joining as: $SELECTED_ROOM ($TIER tier)"
echo "  Your files: $OWNED"
echo ""
echo "  To start working:"
echo "    make agent NAME=$SELECTED_ROOM"
echo ""
if [[ "$TIER" == "starter" ]]; then
  echo "  A lead can promote you to builder after your first contribution."
  echo ""
elif [[ "$TIER" == "lead" ]]; then
  echo "  You're the first member — you have lead access."
  echo "  Promote others with: make promote NAME=username TIER=builder"
  echo ""
fi
