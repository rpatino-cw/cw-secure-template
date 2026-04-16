# Phase 1: Trust Tiers + Role Self-Selection — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user identity, trust tiers, and role self-selection to cw-secure-template so teams can onboard members who get scoped to the right files with the right level of autonomy.

**Architecture:** New `team.json` at project root stores members with room assignments and trust tiers. A new guard module (`trust.sh`) reads this on every PreToolUse call and enforces tier restrictions. `join.sh` presents an interactive menu for self-selection. Promotion/demotion scripts modify `team.json`. Everything hooks into the existing guard dispatcher and Makefile.

**Tech Stack:** Bash (guard scripts), Python3 (JSON parsing — already used by all guards), Make

**Spec:** `docs/specs/2026-04-16-vibe-arch-evolution-design.md` — Features 1 and 2

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `team.json` | Team roster — members, rooms, tiers, join dates |
| Create | `scripts/guards/trust.sh` | Guard module — tier enforcement on every edit |
| Create | `scripts/join.sh` | Interactive role self-selection flow |
| Create | `scripts/promote.sh` | Promote/demote members between tiers |
| Create | `scripts/team-status.sh` | Display team roster with tiers and rooms |
| Modify | `scripts/guard.sh:44` | Add `source trust.sh` before collaboration.sh |
| Modify | `Makefile:53-57` | Add join, promote, demote, team targets |
| Modify | `scripts/guards/test-guards.sh:243` | Add trust tier tests before rooms.sh tests |

---

## Chunk 1: Trust Tier Guard Module

### Task 1: Create team.json with seed data

**Files:**
- Create: `team.json`

- [ ] **Step 1: Create team.json**

```json
{
  "version": 1,
  "members": {}
}
```

This starts empty. `make join` populates it. The schema supports:
```json
{
  "version": 1,
  "members": {
    "username": {
      "room": "room-name",
      "tier": "starter|builder|lead",
      "joined": "YYYY-MM-DD"
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add team.json
git commit -m "feat: add team.json — empty roster for trust tiers"
```

---

### Task 2: Write failing tests for trust.sh

**Files:**
- Modify: `scripts/guards/test-guards.sh`

- [ ] **Step 1: Create a test team.json fixture**

First, update the existing `reset_vars` function to include `VIBE_USER`:

```bash
# Find the existing reset_vars and add VIBE_USER=""
# After AGENT_ROOM="" add:
  VIBE_USER=""
```

Then update `run_guard` to export `VIBE_USER`:

```bash
# In the subshell inside run_guard, add:
    export VIBE_USER="${VIBE_USER:-}"
# alongside the existing exports (TOOL_NAME, FILE_PATH, etc.)
```

Then add this block after the `reset_vars` function definition (after line 60), before any test sections:

```bash
# ── Create test fixtures ──
TEST_TEAM_JSON="$REPO_ROOT/team.json"

setup_test_team() {
  cat > "$TEST_TEAM_JSON" << 'EOF'
{
  "version": 1,
  "members": {
    "test-starter": {
      "room": "go-dev",
      "tier": "starter",
      "joined": "2026-04-16"
    },
    "test-builder": {
      "room": "go-dev",
      "tier": "builder",
      "joined": "2026-03-01"
    },
    "test-lead": {
      "room": "security",
      "tier": "lead",
      "joined": "2026-02-15"
    }
  }
}
EOF
}

cleanup_test_team() {
  # Restore original team.json if it existed, otherwise remove test fixture
  if [[ -f "$TEST_TEAM_JSON.bak" ]]; then
    mv "$TEST_TEAM_JSON.bak" "$TEST_TEAM_JSON"
  else
    rm -f "$TEST_TEAM_JSON"
  fi
}

# Backup existing team.json
[[ -f "$TEST_TEAM_JSON" ]] && cp "$TEST_TEAM_JSON" "$TEST_TEAM_JSON.bak"
setup_test_team
```

- [ ] **Step 2: Add trust.sh test section**

Insert this BEFORE the `# rooms.sh` section (before the line `echo -e "${DIM}  rooms.sh${NC}"`):

```bash
# ═══════════════════════════════════════
# trust.sh
# ═══════════════════════════════════════
echo -e "${DIM}  trust.sh${NC}"

# Starter: can edit files in own room
reset_vars
AGENT_ROOM="go-dev"
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/go/main.go"
CONTENT="func main() {}"
run_guard "trust.sh" "pass" "Starter can edit files in own room"

# Starter: blocked from shared files
reset_vars
AGENT_ROOM=""
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/README.md"
CONTENT="new content"
run_guard "trust.sh" "block" "Starter blocked from shared files"

# Starter: blocked from team.json
reset_vars
AGENT_ROOM=""
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/team.json"
CONTENT="{}"
run_guard "trust.sh" "block" "Starter blocked from team.json"

# Starter: blocked from rooms.json
reset_vars
AGENT_ROOM=""
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/rooms.json"
CONTENT="{}"
run_guard "trust.sh" "block" "Starter blocked from rooms.json"

# Starter: blocked from guard/rule files
reset_vars
AGENT_ROOM=""
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/scripts/guards/security.sh"
CONTENT="echo hi"
run_guard "trust.sh" "block" "Starter blocked from guard files"

# Builder: can edit files in own room
reset_vars
AGENT_ROOM="go-dev"
VIBE_USER="test-builder"
FILE_PATH="$REPO_ROOT/go/main.go"
CONTENT="func main() {}"
run_guard "trust.sh" "pass" "Builder can edit files in own room"

# Builder: blocked from shared files
reset_vars
AGENT_ROOM=""
VIBE_USER="test-builder"
FILE_PATH="$REPO_ROOT/README.md"
CONTENT="new content"
run_guard "trust.sh" "block" "Builder blocked from shared files"

# Lead: can edit shared files
reset_vars
AGENT_ROOM="security"
VIBE_USER="test-lead"
FILE_PATH="$REPO_ROOT/README.md"
CONTENT="new content"
run_guard "trust.sh" "pass" "Lead can edit shared files"

# Lead: can edit team.json
reset_vars
AGENT_ROOM="security"
VIBE_USER="test-lead"
FILE_PATH="$REPO_ROOT/team.json"
CONTENT="{}"
run_guard "trust.sh" "pass" "Lead can edit team.json"

# Lead: can edit rooms.json
reset_vars
AGENT_ROOM="security"
VIBE_USER="test-lead"
FILE_PATH="$REPO_ROOT/rooms.json"
CONTENT="{}"
run_guard "trust.sh" "pass" "Lead can edit rooms.json"

# No identity: warn but allow (graceful degradation)
reset_vars
AGENT_ROOM=""
VIBE_USER=""
FILE_PATH="$REPO_ROOT/go/main.go"
CONTENT="func main() {}"
run_guard "trust.sh" "pass" "No identity: allows action (graceful degradation)"

echo ""
```

- [ ] **Step 3: Add cleanup at the end of test-guards.sh**

Before the final `exit "$FAIL"` line, add:

```bash
# Cleanup test fixtures
cleanup_test_team
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
cd /Users/rpatino/dev/cw-secure-template && bash scripts/guards/test-guards.sh
```

Expected: trust.sh tests all FAIL (file not found or source error). All other tests still PASS.

**Note:** The "Starter blocked from shared files" test depends on `rooms.json` existing with `README.md` in `shared.paths`. This file already exists in the repo. The framework-files check in trust.sh runs BEFORE the shared-files check, so `CLAUDE.md` and `.claude/` are caught as framework files (not shared files). `README.md` is only in shared, not framework — which is why we test with it. Lead access to `CLAUDE.md` and `guard.sh` is enforced by security.sh (already tested), not trust.sh — no duplicate test needed.

- [ ] **Step 5: Commit failing tests**

```bash
git add scripts/guards/test-guards.sh
git commit -m "test: add failing trust tier guard tests (11 cases)"
```

---

### Task 3: Implement trust.sh guard module

**Files:**
- Create: `scripts/guards/trust.sh`

- [ ] **Step 1: Write trust.sh**

```bash
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
```

- [ ] **Step 2: Run tests to verify they pass**

```bash
cd /Users/rpatino/dev/cw-secure-template && bash scripts/guards/test-guards.sh
```

Expected: ALL tests PASS, including the 11 new trust.sh tests.

- [ ] **Step 3: Commit**

```bash
git add scripts/guards/trust.sh
git commit -m "feat: add trust.sh guard — tier-based file access enforcement"
```

---

### Task 4: Wire trust.sh into guard.sh dispatcher

**Files:**
- Modify: `scripts/guard.sh:44-48`

- [ ] **Step 1: Add trust.sh to the dispatch chain**

In `scripts/guard.sh`, between the config-audit source and the collaboration source, add trust.sh:

```bash
# ── Config audit gate (must pass before any other guard) ──
source "$GUARD_DIR/config-audit.sh"

# ── Trust tier enforcement (before room checks) ──
source "$GUARD_DIR/trust.sh"

# ── Run all guards (source so they share variables) ──
source "$GUARD_DIR/collaboration.sh"
```

- [ ] **Step 2: Run full guard tests**

```bash
cd /Users/rpatino/dev/cw-secure-template && bash scripts/guards/test-guards.sh
```

Expected: ALL tests PASS. The trust.sh guard runs first in the chain, existing guards unaffected.

- [ ] **Step 3: Commit**

```bash
git add scripts/guard.sh
git commit -m "feat: wire trust.sh into guard dispatcher (before collaboration)"
```

---

## Chunk 2: Role Self-Selection + Team Management

### Task 5: Write join.sh — interactive role self-selection

**Files:**
- Create: `scripts/join.sh`

- [ ] **Step 1: Write join.sh**

```bash
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

# Read project name from CLAUDE.md or directory
PROJECT_NAME=$(basename "$REPO_ROOT")

# Build menu from rooms.json
echo ""
echo "  Welcome to $PROJECT_NAME."
echo ""
echo "  What are you working on?"

mapfile -t ROOMS < <(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
rooms = config.get('rooms', {})
for i, (name, info) in enumerate(rooms.items(), 1):
    desc = info.get('description', name)
    # Truncate long descriptions
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

# Determine tier
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /Users/rpatino/dev/cw-secure-template/scripts/join.sh
```

- [ ] **Step 3: Test manually**

```bash
cd /Users/rpatino/dev/cw-secure-template && bash scripts/join.sh testuser
```

Expected: shows menu, accepts input, writes to team.json.

- [ ] **Step 4: Verify team.json was updated**

```bash
cat /Users/rpatino/dev/cw-secure-template/team.json
```

Expected: testuser appears with selected room, tier, and today's date.

- [ ] **Step 5: Clean up test data and commit**

```bash
cd /Users/rpatino/dev/cw-secure-template
# Reset team.json to empty
echo '{"version": 1, "members": {}}' > team.json
git add scripts/join.sh team.json
git commit -m "feat: add make join — interactive role self-selection"
```

---

### Task 6: Write promote.sh — tier promotion/demotion

**Files:**
- Create: `scripts/promote.sh`

- [ ] **Step 1: Write promote.sh**

```bash
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
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x /Users/rpatino/dev/cw-secure-template/scripts/promote.sh
git add scripts/promote.sh
git commit -m "feat: add make promote/demote — tier management for leads"
```

---

### Task 7: Write team-status.sh — display team roster

**Files:**
- Create: `scripts/team-status.sh`

- [ ] **Step 1: Write team-status.sh**

```bash
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
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x /Users/rpatino/dev/cw-secure-template/scripts/team-status.sh
git add scripts/team-status.sh
git commit -m "feat: add make team — display team roster with tiers"
```

---

### Task 8: Wire Makefile targets

**Files:**
- Modify: `Makefile`

- [ ] **Step 1: Add team targets to the "4 commands" section**

After `make help` section (after line 57), add:

```makefile
.PHONY: join
join: ## Join the team — pick your role
	@bash scripts/join.sh $(NAME)

.PHONY: team
team: ## Show team roster
	@bash scripts/team-status.sh
```

- [ ] **Step 2: Add promote/demote to the multi-agent section**

After the `room-lint` target (after line 201), add:

```makefile
.PHONY: promote
promote: ## Promote a team member (NAME=alice TIER=builder)
	@bash scripts/promote.sh $(NAME) $(TIER)

.PHONY: demote
demote: ## Demote a team member (NAME=alice TIER=starter)
	@bash scripts/promote.sh $(NAME) $(TIER)
```

- [ ] **Step 3: Update help output**

In the `help` target, add the join and team commands:

```makefile
help: ## Show commands
	@echo ""
	@echo "  CW Secure Framework"
	@echo "  ──────────────────"
	@echo ""
	@echo "    make new         Start from a blueprint"
	@echo "    make start       Run your app"
	@echo "    make check       Run before pushing"
	@echo "    make join        Join the team — pick your role"
	@echo "    make team        Show who's on the team"
	@echo "    make rooms       Set up multi-agent coordination"
	@echo ""
	@echo "  Run 'make help-all' for the full command list."
	@echo ""
```

In the `help-all` target, add to the Multi-agent section:

```
    make team         Show who's on the team
    make promote      Promote a member (NAME=alice TIER=builder)
    make demote       Demote a member (NAME=alice TIER=starter)
```

- [ ] **Step 4: Run make help to verify**

```bash
cd /Users/rpatino/dev/cw-secure-template && make help
```

Expected: shows join and team in the command list.

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat: add make join/team/promote/demote to Makefile"
```

---

### Task 9: Run full test suite and verify

- [ ] **Step 1: Run guard tests**

```bash
cd /Users/rpatino/dev/cw-secure-template && bash scripts/guards/test-guards.sh
```

Expected: ALL tests pass, including 11 new trust.sh tests. No regressions.

- [ ] **Step 2: Test the full join → promote flow**

```bash
cd /Users/rpatino/dev/cw-secure-template
# Join as a starter
echo "2" | bash scripts/join.sh testuser
cat team.json
# Promote to builder
bash scripts/promote.sh testuser builder
cat team.json
# Show team
bash scripts/team-status.sh
# Clean up
echo '{"version": 1, "members": {}}' > team.json
```

- [ ] **Step 3: Test guard enforcement manually**

```bash
cd /Users/rpatino/dev/cw-secure-template
# Add a starter to team.json for testing
python3 -c "
import json
team = {'version': 1, 'members': {'tester': {'room': 'go-dev', 'tier': 'starter', 'joined': '2026-04-16'}}}
with open('team.json', 'w') as f:
    json.dump(team, f, indent=2)
"
# Simulate guard input (starter editing shared file — set AGENT_ROOM for rooms.sh compat)
echo '{"tool_name": "Edit", "tool_input": {"file_path": "'$(pwd)'/README.md", "content": "test"}}' | \
  AGENT_ROOM="go-dev" VIBE_USER="tester" bash scripts/guard.sh 2>&1; echo "Exit: $?"
# Expected: BLOCKED by trust.sh (starter can't edit shared files), Exit: 2

# Clean up
echo '{"version": 1, "members": {}}' > team.json
```

- [ ] **Step 4: Final commit**

```bash
git add team.json
git commit -m "chore: verify Phase 1 — trust tiers + role self-selection complete"
```
