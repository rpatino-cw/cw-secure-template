# guards/security.sh — Secrets, dangerous functions, protected files
# Sourced by guard.sh. Uses: FILE_PATH, CONTENT

# --- Protected guardrail files ---
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
  "scripts/guards/"
)

for protected in "${PROTECTED_FILES[@]}"; do
  if [[ "$FILE_PATH" == *"$protected"* ]]; then
    echo "BLOCKED: Cannot modify guardrail file: $FILE_PATH" >&2
    echo "These files are protected by the repository owner." >&2
    echo "If you need changes, open a PR and have the repo owner review." >&2
    exit 2
  fi
done

# --- Hardcoded secrets ---
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9\-]{20,}'
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

# --- Dangerous functions ---
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
