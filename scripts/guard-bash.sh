#!/usr/bin/env bash
# PreToolUse guard for Bash commands.
# Catches file writes via redirects, heredocs, and pipes that bypass Edit/Write.
# Exit 0 = allow, Exit 2 = block.

set -euo pipefail

INPUT="$(cat)"

# Extract the command string from JSON
COMMAND="$(python3 -c "
import json, sys
data = json.loads(sys.argv[1])
print(data.get('tool_input', {}).get('command', ''))
" "$INPUT")"

# If empty, allow (shouldn't happen)
[[ -z "$COMMAND" ]] && exit 0

# --- Config Audit Gate: block all commands if secure-mode not configured ---
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
if [ ! -f "$REPO_ROOT/.claude/settings.local.json" ]; then
  # Allow make setup / make secure-mode through so user can fix the problem
  if ! echo "$COMMAND" | grep -qE '^make (setup|secure-mode|upgrade)' 2>/dev/null; then
    echo "BLOCKED: Run 'make secure-mode' before using this repo." >&2
    echo "" >&2
    echo "  Your global Claude Code config may override this repo's security guards." >&2
    echo "  Run:  make secure-mode" >&2
    echo "" >&2
    exit 2
  fi
fi

# --- Guard 1: Block redirects that write to protected files ---
PROTECTED_PATTERNS=(
  'CLAUDE\.md'
  '\.claude/'
  '\.claude/settings'
  '\.pre-commit-config'
  '\.github/workflows'
  '\.github/CODEOWNERS'
  'scripts/git-hooks'
  'scripts/guard'
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  # Check for redirect (> or >>) to protected file
  if echo "$COMMAND" | grep -qE ">\s*\S*${pattern}" 2>/dev/null; then
    echo "BLOCKED: Bash redirect to protected file detected" >&2
    echo "Command: $COMMAND" >&2
    echo "Protected files cannot be modified via shell redirects." >&2
    exit 2
  fi
  # Check for tee/dd/cp targeting protected file
  if echo "$COMMAND" | grep -qE "(tee|dd|cp)\s+.*${pattern}" 2>/dev/null; then
    echo "BLOCKED: File write to protected path via $COMMAND" >&2
    exit 2
  fi
done

# --- Guard 2: Block writing dangerous patterns via echo/cat/heredoc to source files ---
SOURCE_EXTENSIONS='\.py|\.go|\.js|\.ts|\.jsx|\.tsx|\.sh|\.sql|\.yaml|\.yml|\.json|\.toml|\.cfg|\.ini'

# Check if command writes to a source file
if echo "$COMMAND" | grep -qE ">\s*\S*(${SOURCE_EXTENSIONS})" 2>/dev/null; then
  # Check for dangerous content in the command itself
  DANGEROUS=(
    'eval\s*\('
    'exec\s*\('
    'pickle'
    'os\.system'
    'shell\s*=\s*True'
    '__import__'
    'sk-[a-zA-Z0-9]{20,}'
    'ghp_[a-zA-Z0-9]{36}'
    'AKIA[A-Z0-9]{16}'
    'password\s*=\s*["\x27]'
  )

  for pattern in "${DANGEROUS[@]}"; do
    if echo "$COMMAND" | grep -qE "$pattern" 2>/dev/null; then
      echo "BLOCKED: Dangerous content in shell redirect to source file" >&2
      echo "Pattern: $pattern" >&2
      echo "Use Edit tool for code changes. Secrets go through: make add-secret" >&2
      exit 2
    fi
  done
fi

# --- Guard 3: Block creation of settings.local.json (hook override attack) ---
if echo "$COMMAND" | grep -qE 'settings\.local\.json' 2>/dev/null; then
  echo "BLOCKED: Cannot create or modify .claude/settings.local.json" >&2
  echo "This file would override the project's security hooks." >&2
  exit 2
fi

# All checks passed
exit 0
