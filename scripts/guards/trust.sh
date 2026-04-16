# guards/trust.sh — Trust tier enforcement
# Sourced by guard.sh. Uses: FILE_PATH, CONTENT, TOOL_NAME, AGENT_ROOM, REPO_ROOT
#
# Tiers: starter (restricted) → builder (room-scoped) → lead (broad access)
# Identity: $AGENT_ROOM → lookup in team.json. Fallback: $VIBE_USER.
# No identity: warn once, allow action (don't block solo users).

TEAM_CONFIG="$REPO_ROOT/team.json"

# Skip if no team.json (framework not using trust tiers yet)
[[ ! -f "$TEAM_CONFIG" ]] && return 0

# Skip if no file being edited
[[ -z "${FILE_PATH:-}" ]] && return 0

# ── Resolve identity ──
VIBE_IDENTITY=""
VIBE_TIER=""

if [[ -n "${AGENT_ROOM:-}" ]]; then
  # Multi-agent mode: find who is assigned to this room
  VIBE_IDENTITY=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    team = json.load(f)
for name, info in team.get('members', {}).items():
    if info.get('room') == sys.argv[2]:
        print(name)
        break
" "$TEAM_CONFIG" "$AGENT_ROOM" 2>/dev/null || echo "")
elif [[ -n "${VIBE_USER:-}" ]]; then
  # Solo mode fallback
  VIBE_IDENTITY="$VIBE_USER"
fi

# No identity found: warn and allow
if [[ -z "$VIBE_IDENTITY" ]]; then
  echo "<trust-warning>No team identity found. Set AGENT_ROOM or VIBE_USER for trust tier enforcement.</trust-warning>"
  return 0
fi

# ── Look up tier ──
VIBE_TIER=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    team = json.load(f)
member = team.get('members', {}).get(sys.argv[2], {})
print(member.get('tier', ''))
" "$TEAM_CONFIG" "$VIBE_IDENTITY" 2>/dev/null || echo "")

# Unknown member: warn and allow
if [[ -z "$VIBE_TIER" ]]; then
  echo "<trust-warning>'$VIBE_IDENTITY' not in team.json. Run 'make join' to register.</trust-warning>"
  return 0
fi

# ── Tier enforcement ──
REL_PATH="${FILE_PATH#$REPO_ROOT/}"
REL_PATH="${REL_PATH#./}"

# Framework files: only leads can touch these
FRAMEWORK_FILES="team.json rooms.json CLAUDE.md .claude/ scripts/guard scripts/guards/"
is_framework_file() {
  for pattern in $FRAMEWORK_FILES; do
    if [[ "$REL_PATH" == $pattern* ]]; then
      return 0
    fi
  done
  return 1
}

# Shared files: defined in rooms.json shared.paths
is_shared_file() {
  [[ ! -f "$REPO_ROOT/rooms.json" ]] && return 1
  python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
shared = config.get('shared', {}).get('paths', [])
path = sys.argv[2]
for s in shared:
    s = s.lstrip('./')
    if path == s or path.startswith(s.rstrip('/') + '/'):
        sys.exit(0)
sys.exit(1)
" "$REPO_ROOT/rooms.json" "$REL_PATH" 2>/dev/null
}

case "$VIBE_TIER" in
  starter)
    # Starters cannot touch framework files
    if is_framework_file; then
      echo "BLOCKED: Starter-tier members cannot edit framework files ($REL_PATH)" >&2
      echo "" >&2
      echo "Ask a lead to make this change, or request a promotion:" >&2
      echo "  make promote NAME=$VIBE_IDENTITY TIER=builder" >&2
      exit 2
    fi
    # Starters cannot touch shared files
    if is_shared_file; then
      echo "BLOCKED: Starter-tier members cannot edit shared files ($REL_PATH)" >&2
      echo "" >&2
      echo "Send a request to the approver's inbox instead." >&2
      echo "  Run 'make room-status' to see the approver." >&2
      exit 2
    fi
    ;;

  builder)
    # Builders cannot touch framework files
    if is_framework_file; then
      echo "BLOCKED: Builder-tier members cannot edit framework files ($REL_PATH)" >&2
      echo "" >&2
      echo "Ask a lead to make this change." >&2
      exit 2
    fi
    # Builders cannot touch shared files directly
    if is_shared_file; then
      echo "BLOCKED: Builder-tier members cannot edit shared files directly ($REL_PATH)" >&2
      echo "" >&2
      echo "Send a request to the approver's inbox instead." >&2
      exit 2
    fi
    ;;

  lead)
    # Leads can touch everything — no restrictions at this layer
    # (CODEOWNERS still enforces PR review for guard.sh and CLAUDE.md)
    ;;
esac
