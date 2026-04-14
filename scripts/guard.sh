#!/usr/bin/env bash
# PreToolUse guard — runs BEFORE Claude writes to any file.
# Claude Code pipes JSON on stdin with tool_name, file_path, content, etc.
# Exit 0 = allow, Exit 2 = block with message on stderr.

set -euo pipefail

# Read JSON from stdin using python3 (guaranteed available — template requires Python 3.11+)
INPUT="$(cat)"

read_field() {
  python3 -c "
import json, sys
data = json.loads(sys.argv[1])
# tool_input holds the parameters for the tool being called
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

# Also extract old_string for Edit tool (needed for dependency guard)
OLD_STRING=$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
print(data.get('tool_input', {}).get('old_string', ''))
" "$INPUT" 2>/dev/null || echo "")

# --- Guard 0: Path traversal check ---
if [[ "$FILE_PATH" == *".."* ]]; then
  echo "BLOCKED: Path traversal detected: $FILE_PATH" >&2
  echo "File paths must not contain '..' components." >&2
  exit 2
fi

# --- Guard 1: Protect guardrail files from modification ---
PROTECTED_FILES=(
  "CLAUDE.md"
  ".claude/settings.json"
  ".claude/settings.local.json"
  ".claude/rules/"
  ".claude/skills/"
  ".claude/agents/"
  ".pre-commit-config.yaml"
  ".github/workflows/ci.yml"
  ".github/CODEOWNERS"
  "scripts/git-hooks/"
  "scripts/guard.sh"
  "scripts/guard-bash.sh"
)

for protected in "${PROTECTED_FILES[@]}"; do
  if [[ "$FILE_PATH" == *"$protected"* ]]; then
    echo "BLOCKED: Cannot modify guardrail file: $FILE_PATH" >&2
    echo "These files are protected by the repository owner." >&2
    echo "If you need changes, open a PR and have the repo owner review." >&2
    exit 2
  fi
done

# --- Guard 2: Check for hardcoded secrets ---
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9]{20,}'
  'ghp_[a-zA-Z0-9]{36}'
  'AKIA[A-Z0-9]{16}'
  'password\s*=\s*["\x27][^"\x27]{8,}'
  'secret\s*=\s*["\x27][^"\x27]+'
  'token\s*=\s*["\x27][^"\x27]+'
  'Bearer [a-zA-Z0-9_\-\.]{20,}'
  'postgres://[^:]+:[^@]+@'
  'mysql://[^:]+:[^@]+@'
  'mongodb://[^:]+:[^@]+@'
  'redis://:[^@]+@'
)

if [[ -n "$CONTENT" ]]; then
  for pattern in "${SECRET_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qE "$pattern" 2>/dev/null; then
      echo "BLOCKED: Hardcoded secret detected in content being written to $FILE_PATH" >&2
      echo "Secrets must NEVER be in code. Use: make add-secret" >&2
      echo "Pattern matched: $pattern" >&2
      exit 2
    fi
  done
fi

# --- Guard 3: Block Write tool on existing files (must use Edit) ---
if [[ "$TOOL_NAME" == "Write" && -f "$FILE_PATH" ]]; then
  LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
  if [[ "$LINE_COUNT" -gt 10 ]]; then
    echo "BLOCKED: Cannot overwrite existing file $FILE_PATH ($LINE_COUNT lines)" >&2
    echo "Use Edit with targeted old_string/new_string instead of Write." >&2
    echo "Write is only for creating NEW files." >&2
    exit 2
  fi
fi

# --- Guard 4: Check for dangerous patterns in code ---
if [[ -n "$CONTENT" ]]; then
  DANGEROUS_PATTERNS=(
    'eval\s*\('
    'exec\s*\('
    'pickle\.loads'
    'os\.system\s*\('
    'subprocess.*shell\s*=\s*True'
    'yaml\.load\s*\('
    '__import__\s*\('
    'InsecureSkipVerify\s*:\s*true'
    'getattr.*exec'
    'getattr.*eval'
    'getattr.*system'
    'compile\s*\(.*exec'
    'os\.popen\s*\('
  )

  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qE "$pattern" 2>/dev/null; then
      echo "BLOCKED: Dangerous function detected: $pattern" >&2
      echo "File: $FILE_PATH" >&2
      echo "This function is banned by the security rules." >&2
      exit 2
    fi
  done
fi

# --- Guard 5: Teammate collision detection ---
# If file has uncommitted changes, someone may be working on it
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
  # Check if file has uncommitted changes (staged or unstaged)
  if git diff --name-only 2>/dev/null | grep -qF "$FILE_PATH" || \
     git diff --cached --name-only 2>/dev/null | grep -qF "$FILE_PATH"; then
    # Check who last modified it
    LAST_AUTHOR=$(git log -1 --format="%an" -- "$FILE_PATH" 2>/dev/null || echo "")
    LAST_TIME=$(git log -1 --format="%ar" -- "$FILE_PATH" 2>/dev/null || echo "")
    echo "WARNING: $FILE_PATH has uncommitted changes" >&2
    if [[ -n "$LAST_AUTHOR" ]]; then
      echo "Last modified by: $LAST_AUTHOR ($LAST_TIME)" >&2
    fi
    echo "Another teammate may be actively editing this file." >&2
    echo "Edit blocked — coordinate with your team or commit/stash their changes first." >&2
    exit 2
  fi
fi

# --- Guard 6: Architecture enforcement — route files must not contain SQL/DB ---
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  SQL_PATTERNS=(
    'SELECT\s+.*\s+FROM\s+'
    'INSERT\s+INTO\s+'
    'UPDATE\s+.*\s+SET\s+'
    'DELETE\s+FROM\s+'
    'cursor\.\s*execute'
    'session\.\s*execute'
    'session\.\s*query'
    'db\.\s*execute'
    '\.raw\s*\('
  )
  for pattern in "${SQL_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qEi "$pattern" 2>/dev/null; then
      echo "BLOCKED: Database query detected in route handler: $FILE_PATH" >&2
      echo "Pattern: $pattern" >&2
      echo "Route handlers must NOT contain SQL or ORM queries." >&2
      echo "Move database access to repositories/ or services/." >&2
      exit 2
    fi
  done
fi

# --- Guard 7: Route handlers must have auth ---
# When a new route decorator/handler is in the edit, check the FULL FILE for auth
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  HAS_NEW_ROUTE=false
  IS_HEALTH=false

  # Detect new route in the edit content
  if echo "$CONTENT" | grep -qE '@(app|router)\.(get|post|put|delete|patch)' 2>/dev/null; then
    HAS_NEW_ROUTE=true
  fi
  if echo "$CONTENT" | grep -qE '(HandleFunc|Handle)\s*\(' 2>/dev/null; then
    HAS_NEW_ROUTE=true
  fi

  # Health endpoints are exempt
  if echo "$CONTENT" | grep -qE '(healthz|health|readyz|livez)' 2>/dev/null; then
    IS_HEALTH=true
  fi

  if [[ "$HAS_NEW_ROUTE" == true && "$IS_HEALTH" == false ]]; then
    # Check the FULL FILE on disk (not just the edit) for auth patterns
    FULL_FILE=""
    if [[ -f "$FILE_PATH" ]]; then
      FULL_FILE=$(cat "$FILE_PATH" 2>/dev/null || echo "")
    fi
    # Combine: existing file + new content being added
    COMBINED="${FULL_FILE}${CONTENT}"

    if ! echo "$COMBINED" | grep -qE '(Depends\s*\(\s*get_current_user|current_user|RequireAuth|AuthMiddleware|WithAuth|authenticate)' 2>/dev/null; then
      echo "BLOCKED: Route endpoint in $FILE_PATH missing authentication" >&2
      echo "Every endpoint (except /healthz) requires auth middleware." >&2
      echo "Python: Add Depends(get_current_user) to endpoint parameters." >&2
      echo "Go: Wrap handler with RequireAuth(handler)." >&2
      echo "For local dev without Okta, set DEV_MODE=true in .env." >&2
      exit 2
    fi
  fi
fi

# --- Guard 8: Dependency direction enforcement ---
# models/ must not import from routes/, services/, or repositories/
if [[ -n "$CONTENT" && "$FILE_PATH" == *"models/"* ]]; then
  # Python imports
  if echo "$CONTENT" | grep -qE '(from\s+(routes|services|repositories|handlers|delivery)|import\s+.*(routes|services|repositories|handlers|delivery))' 2>/dev/null; then
    echo "BLOCKED: Invalid import in model file: $FILE_PATH" >&2
    echo "models/ must NOT import from routes/, services/, or repositories/" >&2
    echo "Dependency direction: models depend on NOTHING. Everything else depends on models." >&2
    exit 2
  fi
  # Go imports
  if echo "$CONTENT" | grep -qE '"[^"]*/(routes|services|repository|handlers|delivery|controller)"' 2>/dev/null; then
    echo "BLOCKED: Invalid import in model file: $FILE_PATH" >&2
    echo "models/ must NOT import from routes/, services/, or repositories/" >&2
    exit 2
  fi
fi
# routes/ must not import from repositories/ directly
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  # Python imports
  if echo "$CONTENT" | grep -qE '(from\s+(repositories|repo|db)|import\s+.*(repositories|repo))' 2>/dev/null; then
    echo "BLOCKED: Route handler importing directly from repository: $FILE_PATH" >&2
    echo "routes/ must call services/, not repositories/ directly." >&2
    echo "Dependency direction: routes -> services -> repositories -> models" >&2
    exit 2
  fi
  # Go imports
  if echo "$CONTENT" | grep -qE '"[^"]*/(repository|repo|db)"' 2>/dev/null; then
    echo "BLOCKED: Route handler importing directly from repository: $FILE_PATH" >&2
    echo "routes/ must call services/, not repositories/ directly." >&2
    exit 2
  fi
fi

# --- Guard 9: Room enforcement — agents can only edit files in their room ---
if [[ -n "${AGENT_ROOM:-}" && -n "$FILE_PATH" ]]; then
  ROOMS_CONFIG="$(git rev-parse --show-toplevel 2>/dev/null)/rooms.json"
  if [[ -f "$ROOMS_CONFIG" ]]; then
    # Get the list of paths this agent owns
    ALLOWED=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
room = config.get('rooms', {}).get(sys.argv[2], {})
for p in room.get('owns', []):
    print(p)
" "$ROOMS_CONFIG" "$AGENT_ROOM" 2>/dev/null || echo "")

    if [[ -n "$ALLOWED" ]]; then
      IN_ROOM=false
      # Normalize file path: strip leading ./ and resolve to repo-relative
      REPO_TOP="$(git rev-parse --show-toplevel 2>/dev/null)/"
      REL_PATH="${FILE_PATH#$REPO_TOP}"
      REL_PATH="${REL_PATH#./}"
      while IFS= read -r owned_path; do
        [[ -z "$owned_path" ]] && continue
        owned_path="${owned_path#./}"
        # Anchored match: path must START with the owned path
        if [[ "$REL_PATH" == "$owned_path"* ]]; then
          IN_ROOM=true
          break
        fi
      done <<< "$ALLOWED"

      # Also check inbox/outbox (agents can always write to rooms/)
      if [[ "$FILE_PATH" == *"rooms/"* ]]; then
        IN_ROOM=true
      fi

      if [[ "$IN_ROOM" == false ]]; then
        echo "BLOCKED: Agent '$AGENT_ROOM' cannot edit $FILE_PATH" >&2
        echo "" >&2
        echo "You own: $ALLOWED" >&2
        echo "" >&2
        echo "To request a change in this file, write to the owning room's inbox:" >&2
        echo "  rooms/{owner}/inbox/NNN-from-${AGENT_ROOM}.md" >&2
        echo "" >&2
        echo "Run 'make room-status' to see all rooms and their owners." >&2
        exit 2
      fi
    fi
  fi
fi

# --- Guard 10: Dependency protection — block deleting functions used by other rooms ---
if [[ "$TOOL_NAME" == "Edit" && -n "$OLD_STRING" && -n "${AGENT_ROOM:-}" && -n "$FILE_PATH" ]]; then
  REPO_TOP="$(git rev-parse --show-toplevel 2>/dev/null)"
  ROOMS_CONFIG="$REPO_TOP/rooms.json"

  if [[ -f "$ROOMS_CONFIG" ]]; then
    # Find function/class names being REMOVED (in old_string but not in new_string)
    REMOVED_NAMES=$(python3 -c "
import re, sys

old = sys.argv[1]
new = sys.argv[2]

# Extract function/class/method names from definitions
patterns = [
    r'(?:^|\n)\s*def\s+(\w+)\s*\(',           # Python def
    r'(?:^|\n)\s*class\s+(\w+)',                # Python class
    r'(?:^|\n)\s*func\s+(\w+)\s*\(',           # Go func
    r'(?:^|\n)\s*func\s+\([^)]+\)\s+(\w+)\s*\(', # Go method
    r'(?:^|\n)\s*(?:export\s+)?function\s+(\w+)', # JS function
    r'(?:^|\n)\s*(?:export\s+)?const\s+(\w+)\s*=', # JS const export
]

old_names = set()
for p in patterns:
    old_names.update(re.findall(p, old))

new_names = set()
for p in patterns:
    new_names.update(re.findall(p, new))

# Names that were in old but NOT in new = removed
removed = old_names - new_names
# Filter out very short names and common patterns (avoid false positives)
removed = {n for n in removed if len(n) > 2 and n not in ('main', 'init', 'new', 'get', 'set', 'run', 'test')}

for name in sorted(removed):
    print(name)
" "$OLD_STRING" "$CONTENT" 2>/dev/null || echo "")

    if [[ -n "$REMOVED_NAMES" ]]; then
      while IFS= read -r func_name; do
        [[ -z "$func_name" ]] && continue

        # Grep the codebase for references to this function (exclude the file being edited)
        REFS=$(grep -rn --include="*.go" --include="*.py" --include="*.js" --include="*.ts" \
          -w "$func_name" "$REPO_TOP" 2>/dev/null \
          | grep -v "$FILE_PATH" \
          | grep -v "_test\." \
          | grep -v "rooms/" \
          | head -5 || true)

        if [[ -n "$REFS" ]]; then
          # Check if any references are outside this agent's room
          OUTSIDE=""
          ALLOWED=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    config = json.load(f)
room = config.get('rooms', {}).get(sys.argv[2], {})
for p in room.get('owns', []):
    print(p)
" "$ROOMS_CONFIG" "$AGENT_ROOM" 2>/dev/null || echo "")

          while IFS= read -r ref_line; do
            [[ -z "$ref_line" ]] && continue
            ref_file=$(echo "$ref_line" | cut -d: -f1)
            ref_rel="${ref_file#$REPO_TOP/}"

            IN_MY_ROOM=false
            while IFS= read -r owned; do
              [[ -z "$owned" ]] && continue
              owned="${owned#./}"
              if [[ "$ref_rel" == "$owned"* ]]; then
                IN_MY_ROOM=true
                break
              fi
            done <<< "$ALLOWED"

            if [[ "$IN_MY_ROOM" == false ]]; then
              OUTSIDE="${OUTSIDE}  ${ref_line}\n"
            fi
          done <<< "$REFS"

          if [[ -n "$OUTSIDE" ]]; then
            echo "BLOCKED: Removing '$func_name' would break code in other rooms" >&2
            echo "" >&2
            echo "These files reference '$func_name':" >&2
            echo -e "$OUTSIDE" >&2
            echo "Coordinate with the owning agent before removing this function." >&2
            echo "Send a request to their inbox: rooms/{room}/inbox/" >&2
            exit 2
          fi
        fi
      done <<< "$REMOVED_NAMES"
    fi
  fi
fi

# All checks passed
exit 0
