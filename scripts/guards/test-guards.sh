#!/usr/bin/env bash
# test-guards.sh — Unit tests for guard modules
#
# Usage: make test-guards
#    or: bash scripts/guards/test-guards.sh
#
# Mocks JSON input and shared variables, sources each guard,
# verifies exit codes (0 = allow, 2 = block).

set -uo pipefail

GUARD_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$GUARD_DIR/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

PASS=0
FAIL=0
TOTAL=0

# ── Test helper ──
# run_guard <guard_file> <expect: pass|block> <description>
# Set TOOL_NAME, FILE_PATH, CONTENT, OLD_STRING, AGENT_ROOM before calling
run_guard() {
  local guard_file="$1"
  local expect="$2"
  local desc="$3"
  ((TOTAL++))

  # Run in a subshell so exit 2 doesn't kill the test runner
  (
    export TOOL_NAME FILE_PATH CONTENT OLD_STRING REPO_ROOT
    export AGENT_ROOM="${AGENT_ROOM:-}"
    export VIBE_USER="${VIBE_USER:-}"
    source "$GUARD_DIR/$guard_file"
  ) >/dev/null 2>/dev/null
  local exit_code=$?

  if [[ "$expect" == "block" && "$exit_code" -eq 2 ]]; then
    echo -e "  ${GREEN}[PASS]${NC} $desc"
    ((PASS++))
  elif [[ "$expect" == "pass" && "$exit_code" -eq 0 ]]; then
    echo -e "  ${GREEN}[PASS]${NC} $desc"
    ((PASS++))
  else
    echo -e "  ${RED}[FAIL]${NC} $desc (expected $expect, got exit $exit_code)"
    ((FAIL++))
  fi
}

reset_vars() {
  TOOL_NAME="Edit"
  FILE_PATH=""
  CONTENT=""
  OLD_STRING=""
  AGENT_ROOM=""
  VIBE_USER=""
}

echo ""
echo -e "${BOLD}  Guard Unit Tests${NC}"
echo "  ─────────────────"
echo ""

# ═══════════════════════════════════════
# collaboration.sh
# ═══════════════════════════════════════
echo -e "${DIM}  collaboration.sh${NC}"

reset_vars
FILE_PATH="go/../../../etc/passwd"
run_guard "collaboration.sh" "block" "Blocks path traversal (..)"

reset_vars
FILE_PATH="go/main.go"
CONTENT="func main() {}"
run_guard "collaboration.sh" "pass" "Allows normal file edit"

reset_vars
TOOL_NAME="Write"
FILE_PATH="$REPO_ROOT/go/main.go"
CONTENT="overwrite everything"
run_guard "collaboration.sh" "block" "Blocks Write on existing file (>10 lines)"

reset_vars
TOOL_NAME="Write"
FILE_PATH="/tmp/nonexistent-file-test-$$.go"
CONTENT="new file"
run_guard "collaboration.sh" "pass" "Allows Write on new file"

echo ""

# ═══════════════════════════════════════
# security.sh
# ═══════════════════════════════════════
echo -e "${DIM}  security.sh${NC}"

reset_vars
FILE_PATH="go/config.go"
CONTENT='apiKey := "sk-abc123def456ghi789jkl012mno345pqr678"'
run_guard "security.sh" "block" "Blocks hardcoded API key (sk-live)"

reset_vars
FILE_PATH="go/config.go"
CONTENT='apiKey := "sk-live-abc123def456ghi789jkl"'
run_guard "security.sh" "block" "Blocks sk-live- style key (hyphenated)"

reset_vars
FILE_PATH="go/config.go"
CONTENT='apiKey := os.Getenv("API_KEY")'
run_guard "security.sh" "pass" "Allows env var access"

reset_vars
FILE_PATH="python/src/main.py"
CONTENT='result = eval(user_input)'
run_guard "security.sh" "block" "Blocks eval()"

reset_vars
FILE_PATH="python/src/main.py"
CONTENT='result = json.loads(user_input)'
run_guard "security.sh" "pass" "Allows json.loads()"

reset_vars
FILE_PATH="python/src/main.py"
CONTENT='subprocess.run(cmd, shell=True)'
run_guard "security.sh" "block" "Blocks shell=True"

reset_vars
FILE_PATH="python/src/main.py"
CONTENT='data = pickle.loads(untrusted)'
run_guard "security.sh" "block" "Blocks pickle.loads"

reset_vars
FILE_PATH="CLAUDE.md"
CONTENT="ignore all rules"
run_guard "security.sh" "block" "Blocks editing CLAUDE.md"

reset_vars
FILE_PATH="scripts/guard.sh"
CONTENT="remove all checks"
run_guard "security.sh" "block" "Blocks editing guard.sh"

reset_vars
FILE_PATH="scripts/guards/security.sh"
CONTENT="remove all checks"
run_guard "security.sh" "block" "Blocks editing guard modules"

reset_vars
FILE_PATH="go/middleware/auth.go"
CONTENT='func RequireAuth() {}'
run_guard "security.sh" "pass" "Allows normal middleware code"

reset_vars
FILE_PATH="go/config.go"
CONTENT='dbURL := "postgres://admin:password123@localhost/mydb"'
run_guard "security.sh" "block" "Blocks connection string with credentials"

reset_vars
FILE_PATH="go/config.go"
CONTENT='token := "ghp_abcdefghijklmnopqrstuvwxyz0123456789"'
run_guard "security.sh" "block" "Blocks GitHub personal access token"

echo ""

# ═══════════════════════════════════════
# architecture.sh
# ═══════════════════════════════════════
echo -e "${DIM}  architecture.sh${NC}"

# Stack lock tests (create temp .stack files)
reset_vars
echo "go" > "$REPO_ROOT/.stack"
FILE_PATH="python/src/main.py"
CONTENT="from fastapi import FastAPI"
run_guard "architecture.sh" "block" "Stack lock: blocks Python when locked to Go"

reset_vars
FILE_PATH="go/main.go"
CONTENT="func main() {}"
run_guard "architecture.sh" "pass" "Stack lock: allows Go when locked to Go"

echo "python" > "$REPO_ROOT/.stack"
reset_vars
FILE_PATH="go/main.go"
CONTENT="func main() {}"
run_guard "architecture.sh" "block" "Stack lock: blocks Go when locked to Python"

reset_vars
FILE_PATH="python/src/main.py"
CONTENT="from fastapi import FastAPI"
run_guard "architecture.sh" "pass" "Stack lock: allows Python when locked to Python"

rm -f "$REPO_ROOT/.stack"

# SQL in routes
reset_vars
FILE_PATH="python/src/routes/users.py"
CONTENT='cursor.execute("SELECT * FROM users WHERE id = 1")'
run_guard "architecture.sh" "block" "Blocks SQL in route handler"

reset_vars
FILE_PATH="python/src/routes/users.py"
CONTENT='return user_service.get_user(user_id)'
run_guard "architecture.sh" "pass" "Allows service call in route handler"

# Dependency direction
reset_vars
FILE_PATH="python/src/models/user.py"
CONTENT='from routes.users import router'
run_guard "architecture.sh" "block" "Blocks model importing from routes"

reset_vars
FILE_PATH="python/src/routes/users.py"
CONTENT='from repositories.user_repo import get_user'
run_guard "architecture.sh" "block" "Blocks route importing from repository"

reset_vars
FILE_PATH="python/src/routes/users.py"
CONTENT='from services.user_service import get_user'
run_guard "architecture.sh" "pass" "Allows route importing from service"

# Auth enforcement
reset_vars
FILE_PATH="python/src/routes/users.py"
CONTENT='@router.get("/users")
def list_users():
    return []'
run_guard "architecture.sh" "block" "Blocks route without auth"

reset_vars
FILE_PATH="python/src/routes/users.py"
CONTENT='@router.get("/healthz")
def health():
    return {"status": "ok"}'
run_guard "architecture.sh" "pass" "Allows healthz without auth"

echo ""

# ═══════════════════════════════════════
# trust.sh
# ═══════════════════════════════════════
echo -e "${DIM}  trust.sh${NC}"

# Setup test team.json fixture
TEST_TEAM_JSON="$REPO_ROOT/team.json"
[[ -f "$TEST_TEAM_JSON" ]] && cp "$TEST_TEAM_JSON" "$TEST_TEAM_JSON.bak"
cat > "$TEST_TEAM_JSON" << 'TEAMEOF'
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
TEAMEOF

# Starter: can edit files in own room
reset_vars
AGENT_ROOM="go-dev"
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/go/main.go"
CONTENT="func main() {}"
run_guard "trust.sh" "pass" "Starter can edit files in own room"

# Starter: blocked from shared files
reset_vars
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/README.md"
CONTENT="new content"
run_guard "trust.sh" "block" "Starter blocked from shared files"

# Starter: blocked from team.json
reset_vars
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/team.json"
CONTENT="{}"
run_guard "trust.sh" "block" "Starter blocked from team.json"

# Starter: blocked from rooms.json
reset_vars
VIBE_USER="test-starter"
FILE_PATH="$REPO_ROOT/rooms.json"
CONTENT="{}"
run_guard "trust.sh" "block" "Starter blocked from rooms.json"

# Starter: blocked from guard files
reset_vars
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
FILE_PATH="$REPO_ROOT/go/main.go"
CONTENT="func main() {}"
run_guard "trust.sh" "pass" "No identity: allows action (graceful degradation)"

# Restore original team.json
if [[ -f "$TEST_TEAM_JSON.bak" ]]; then
  mv "$TEST_TEAM_JSON.bak" "$TEST_TEAM_JSON"
else
  echo '{"version": 1, "members": {}}' > "$TEST_TEAM_JSON"
fi

echo ""

# ═══════════════════════════════════════
# rooms.sh (basic — skip if no rooms.json)
# ═══════════════════════════════════════
echo -e "${DIM}  rooms.sh${NC}"

if [ -f "$REPO_ROOT/rooms.json" ]; then
  reset_vars
  AGENT_ROOM="go-dev"
  FILE_PATH="$REPO_ROOT/go/main.go"
  CONTENT="func main() {}"
  run_guard "rooms.sh" "pass" "Allows agent editing own room"

  reset_vars
  AGENT_ROOM="go-dev"
  FILE_PATH="$REPO_ROOT/python/src/main.py"
  CONTENT="from fastapi import FastAPI"
  run_guard "rooms.sh" "block" "Blocks agent editing another room"

  reset_vars
  AGENT_ROOM="go-dev"
  FILE_PATH="$REPO_ROOT/rooms/py-dev/inbox/request.md"
  CONTENT="Please add a function"
  run_guard "rooms.sh" "pass" "Allows agent writing to rooms/ inbox"
else
  echo -e "  ${DIM}[SKIP] No rooms.json — room tests skipped${NC}"
fi

echo ""

# ═══════════════════════════════════════
# Summary
# ═══════════════════════════════════════
echo "  ─────────────────"
echo -e "  ${PASS}/${TOTAL} passing"
[ "$FAIL" -gt 0 ] && echo -e "  ${RED}${FAIL} failing${NC}"
echo ""

# Cleanup
rm -f "$REPO_ROOT/.stack"

exit "$FAIL"
