# guards/quality.sh — Code quality enforcement
# Sourced by guard.sh (guard-time mode) OR run standalone (full-scan mode).
#
# Guard-time: checks the single file being edited. Warns only.
# Full-scan:  checks the entire codebase. Blocks on production/strict.
#
# Usage:
#   Sourced by guard.sh          → guard-time (uses FILE_PATH, CONTENT from guard.sh)
#   bash quality.sh --full-scan  → full-scan (scans all source files)

# ── Profile ──
PROFILE=$(cat "$REPO_ROOT/.enforcement-profile" 2>/dev/null || echo "balanced")

case "$PROFILE" in
  hackathon)  MISSING_TEST_ACTION="warn"; LINE_LIMIT_ACTION="warn" ;;
  balanced)   MISSING_TEST_ACTION="warn"; LINE_LIMIT_ACTION="warn" ;;
  strict)     MISSING_TEST_ACTION="block"; LINE_LIMIT_ACTION="warn" ;;
  production) MISSING_TEST_ACTION="block"; LINE_LIMIT_ACTION="block" ;;
esac

QUALITY_WARNINGS=""
QUALITY_BLOCKS=""

quality_warn() {
  QUALITY_WARNINGS="${QUALITY_WARNINGS}  - $1\n"
}

quality_block() {
  QUALITY_BLOCKS="${QUALITY_BLOCKS}  - $1\n"
}

# ── Check: source file has matching test file ──
check_test_exists() {
  local file="$1"
  local rel="${file#$REPO_ROOT/}"

  # Only check source files in testable directories
  case "$rel" in
    */services/*|*/routes/*|*/repositories/*|*/handlers/*|*/middleware/*)
      ;;
    *) return 0 ;;
  esac

  # Skip test files themselves
  case "$rel" in
    *_test.go|*_test.py|*/test_*|*/tests/*) return 0 ;;
  esac

  local basename=$(basename "$file")
  local name_no_ext="${basename%.*}"
  local ext="${basename##*.}"
  local found=false

  if [[ "$ext" == "py" ]]; then
    # Python: check tests/test_{name}.py or tests/{subdir}/test_{name}.py
    for candidate in \
      "$REPO_ROOT/python/tests/test_${name_no_ext}.py" \
      "$REPO_ROOT/tests/test_${name_no_ext}.py"; do
      [[ -f "$candidate" ]] && found=true && break
    done
    # Also search recursively
    if [[ "$found" == false ]]; then
      local search=$(find "$REPO_ROOT" -name "test_${name_no_ext}.py" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -1)
      [[ -n "$search" ]] && found=true
    fi
  elif [[ "$ext" == "go" ]]; then
    # Go: check {name}_test.go in same directory
    local dir=$(dirname "$file")
    [[ -f "$dir/${name_no_ext}_test.go" ]] && found=true
  fi

  if [[ "$found" == false ]]; then
    if [[ "$MISSING_TEST_ACTION" == "block" ]]; then
      quality_block "No test file for $rel — create test_${name_no_ext}.${ext} before shipping"
    else
      quality_warn "No test file for $rel — consider adding test_${name_no_ext}.${ext}"
    fi
  fi
}

# ── Check: file exceeds 300 lines ──
check_line_count() {
  local file="$1"
  local rel="${file#$REPO_ROOT/}"

  # Skip non-source files
  case "$rel" in
    *.go|*.py|*.js|*.ts|*.jsx|*.tsx) ;;
    *) return 0 ;;
  esac

  local lines
  lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
  if [[ "$lines" -gt 300 ]]; then
    if [[ "$LINE_LIMIT_ACTION" == "block" ]]; then
      quality_block "$rel is $lines lines (limit: 300) — split into smaller modules"
    else
      quality_warn "$rel is $lines lines (limit: 300) — consider splitting"
    fi
  fi
}

# ── Check: TODO without ticket number ──
check_todos() {
  local file="$1"
  local rel="${file#$REPO_ROOT/}"

  # Only check source files
  case "$rel" in
    *.go|*.py|*.js|*.ts) ;;
    *) return 0 ;;
  esac

  # Find TODOs without a ticket pattern (DO-XXXXX, HO-XXXXX, JIRA-XXX, #NNN)
  local bare_todos
  bare_todos=$(grep -n "TODO" "$file" 2>/dev/null | grep -v -E "(DO-[0-9]+|HO-[0-9]+|MRB-[0-9]+|JIRA-[0-9]+|#[0-9]+)" | head -3)
  if [[ -n "$bare_todos" ]]; then
    quality_warn "TODOs without ticket numbers in $rel — add a ticket reference (e.g. TODO(DO-12345))"
  fi
}

# ── Execution modes ──
if [[ "${1:-}" == "--full-scan" ]]; then
  # Full-scan mode: check all source files
  REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

  echo "  Running quality checks ($PROFILE profile)..."
  echo ""

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    check_test_exists "$file"
    check_line_count "$file"
    check_todos "$file"
  done < <(find "$REPO_ROOT" \
    \( -name "*.go" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/venv/*" \
    -not -path "*/.venv/*" \
    -not -path "*_test.go" \
    -not -path "*/test_*" \
    -not -path "*/tests/*" \
    -not -name "test-guards.sh" \
    2>/dev/null)

  # Report results
  if [[ -n "$QUALITY_WARNINGS" ]]; then
    echo "  Warnings:"
    echo -e "$QUALITY_WARNINGS"
  fi

  if [[ -n "$QUALITY_BLOCKS" ]]; then
    echo "  Blocking issues:"
    echo -e "$QUALITY_BLOCKS"
    echo "  Fix these before pushing."
    exit 1
  fi

  if [[ -z "$QUALITY_WARNINGS" && -z "$QUALITY_BLOCKS" ]]; then
    echo "  All quality checks passed."
  fi

  exit 0
else
  # Guard-time mode: check the single file being edited
  [[ -z "${FILE_PATH:-}" ]] && return 0

  check_test_exists "$FILE_PATH"
  check_line_count "$FILE_PATH"
  check_todos "$FILE_PATH"

  # Output warnings as context tags (advisory, never blocks in guard-time)
  if [[ -n "$QUALITY_WARNINGS" || -n "$QUALITY_BLOCKS" ]]; then
    echo "<quality-check>"
    [[ -n "$QUALITY_WARNINGS" ]] && echo -e "$QUALITY_WARNINGS"
    [[ -n "$QUALITY_BLOCKS" ]] && echo -e "$QUALITY_BLOCKS"
    echo "</quality-check>"
  fi
fi
