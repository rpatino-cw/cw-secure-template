#!/usr/bin/env bash
# PreToolUse guard — runs BEFORE Claude writes to any file.
# Checks for violations that rules alone can't enforce.
# Exit 0 = allow, Exit 2 = block with message.

set -euo pipefail

# The file path Claude is about to edit/write
FILE_PATH="${CLAUDE_FILE_PATH:-}"
TOOL_NAME="${CLAUDE_TOOL_NAME:-}"
CONTENT="${CLAUDE_CONTENT:-}"

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
    echo "BLOCKED: Cannot modify guardrail file: $FILE_PATH"
    echo "These files are protected by the repository owner."
    echo "If you need changes, open a PR and have the repo owner review."
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
      echo "BLOCKED: Hardcoded secret detected in content being written to $FILE_PATH"
      echo "Secrets must NEVER be in code. Use: make add-secret"
      echo "Pattern matched: $pattern"
      exit 2
    fi
  done
fi

# --- Guard 3: Block Write tool on existing files (must use Edit) ---
if [[ "$TOOL_NAME" == "Write" && -f "$FILE_PATH" ]]; then
  LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
  if [[ "$LINE_COUNT" -gt 10 ]]; then
    echo "BLOCKED: Cannot overwrite existing file $FILE_PATH ($LINE_COUNT lines)"
    echo "Use Edit with targeted old_string/new_string instead of Write."
    echo "Write is only for creating NEW files."
    exit 2
  fi
fi

# --- Guard 4: Check for dangerous patterns in code ---
if [[ -n "$CONTENT" ]]; then
  DANGEROUS_PATTERNS=(
    'eval('
    'exec('
    'pickle\.loads'
    'os\.system('
    'subprocess.*shell=True'
    'yaml\.load('
    '__import__('
    'InsecureSkipVerify:\s*true'
  )

  for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if echo "$CONTENT" | grep -qE "$pattern" 2>/dev/null; then
      echo "BLOCKED: Dangerous function detected: $pattern"
      echo "File: $FILE_PATH"
      echo "This function is banned by the security rules."
      exit 2
    fi
  done
fi

# All checks passed
exit 0
