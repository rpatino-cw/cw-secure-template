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
  'password\s*=\s*["\x27][^"\x27]+'
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
    echo "Proceeding — but coordinate with your team to avoid conflicts." >&2
    # Warning only, not a block — exit 0 continues but the message is injected
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
# Check if a new route/endpoint is being added without auth middleware
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  # Python: check for route decorators without Depends(get_current_user)
  if echo "$CONTENT" | grep -qE '@(app|router)\.(get|post|put|delete|patch)' 2>/dev/null; then
    if ! echo "$CONTENT" | grep -qE '(Depends\s*\(\s*get_current_user|current_user|RequireAuth|authenticate)' 2>/dev/null; then
      # Exception: healthz endpoint doesn't need auth
      if ! echo "$CONTENT" | grep -qE '(healthz|health|readyz|livez)' 2>/dev/null; then
        echo "BLOCKED: Route endpoint in $FILE_PATH missing authentication" >&2
        echo "Every endpoint (except /healthz) requires auth middleware." >&2
        echo "Add: Depends(get_current_user) to the endpoint parameters." >&2
        echo "For local dev without Okta, set DEV_MODE=true in .env." >&2
        exit 2
      fi
    fi
  fi
  # Go: check for http.HandleFunc without auth middleware
  if echo "$CONTENT" | grep -qE '(HandleFunc|Handle)\s*\(' 2>/dev/null; then
    if ! echo "$CONTENT" | grep -qE '(RequireAuth|AuthMiddleware|WithAuth|authenticate)' 2>/dev/null; then
      if ! echo "$CONTENT" | grep -qE '(healthz|health|readyz|livez)' 2>/dev/null; then
        echo "BLOCKED: Route handler in $FILE_PATH missing authentication" >&2
        echo "Every handler (except /healthz) requires auth middleware." >&2
        echo "Wrap with: RequireAuth(handler)" >&2
        exit 2
      fi
    fi
  fi
fi

# --- Guard 8: Dependency direction enforcement ---
# models/ must not import from routes/, services/, or repositories/
if [[ -n "$CONTENT" && "$FILE_PATH" == *"models/"* ]]; then
  if echo "$CONTENT" | grep -qE '(from\s+(routes|services|repositories|handlers|delivery)|import\s+.*(routes|services|repositories|handlers|delivery))' 2>/dev/null; then
    echo "BLOCKED: Invalid import in model file: $FILE_PATH" >&2
    echo "models/ must NOT import from routes/, services/, or repositories/" >&2
    echo "Dependency direction: models depend on NOTHING. Everything else depends on models." >&2
    exit 2
  fi
fi
# routes/ must not import from repositories/ directly
if [[ -n "$CONTENT" && "$FILE_PATH" == *"routes/"* ]]; then
  if echo "$CONTENT" | grep -qE '(from\s+(repositories|repo|db)|import\s+.*(repositories|repo))' 2>/dev/null; then
    echo "BLOCKED: Route handler importing directly from repository: $FILE_PATH" >&2
    echo "routes/ must call services/, not repositories/ directly." >&2
    echo "Dependency direction: routes → services → repositories → models" >&2
    exit 2
  fi
fi

# All checks passed
exit 0
