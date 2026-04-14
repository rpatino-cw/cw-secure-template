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
  ".claude/rules/"
  ".claude/skills/"
  ".claude/agents/"
  ".pre-commit-config.yaml"
  ".github/workflows/ci.yml"
  ".github/CODEOWNERS"
  "scripts/git-hooks/"
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

# All checks passed
exit 0
