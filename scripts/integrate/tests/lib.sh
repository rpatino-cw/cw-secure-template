#!/usr/bin/env bash
# Shared helpers for integration test fixtures.
# Each fixture sources this, calls `setup <name>`, builds state, calls
# `assert_*` helpers, then `teardown`. Exit code propagates to the harness.

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
INTEGRATE_DIR="$TEMPLATE_ROOT/scripts/integrate"

FIXTURE_NAME=""
FIXTURE_DIR=""
FAIL_COUNT=0

setup() {
  FIXTURE_NAME="${1:-unnamed}"
  FIXTURE_DIR="$(mktemp -d -t "cw-fixture-${FIXTURE_NAME}.XXXXXX")"
  echo -e "${BOLD}[$FIXTURE_NAME]${NC} ${DIM}$FIXTURE_DIR${NC}"
  cd "$FIXTURE_DIR"
}

teardown() {
  cd /tmp
  rm -rf "$FIXTURE_DIR"
  if [ "$FAIL_COUNT" -eq 0 ]; then
    echo -e "  ${GREEN}✓ PASS${NC}  $FIXTURE_NAME"
    return 0
  else
    echo -e "  ${RED}✗ FAIL${NC}  $FIXTURE_NAME ($FAIL_COUNT assertions)"
    return 1
  fi
}

fail() {
  echo -e "    ${RED}✗${NC} $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

pass() {
  echo -e "    ${GREEN}✓${NC} $1"
}

# ── Assertions ──

assert_file_exists() {
  if [ -f "$1" ]; then pass "file exists: $1"; else fail "missing file: $1"; fi
}

assert_dir_exists() {
  if [ -d "$1" ]; then pass "dir exists: $1"; else fail "missing dir: $1"; fi
}

assert_contains() {
  local file="$1" needle="$2" label="${3:-contains needle}"
  if grep -qF -- "$needle" "$file"; then pass "$label"; else fail "$label — not found in $file"; fi
}

assert_not_contains() {
  local file="$1" needle="$2" label="${3:-does not contain}"
  if ! grep -qF -- "$needle" "$file"; then pass "$label"; else fail "$label — FOUND in $file"; fi
}

assert_marker_count() {
  local file="$1" marker="$2" expected="$3"
  local count
  count="$(grep -cF -- "$marker" "$file" 2>/dev/null || echo 0)"
  if [ "$count" -eq "$expected" ]; then
    pass "marker count $expected: $marker"
  else
    fail "marker count mismatch (got $count, expected $expected): $marker"
  fi
}

assert_exit_code() {
  local expected="$1" actual="$2" label="${3:-exit code}"
  if [ "$actual" -eq "$expected" ]; then
    pass "$label = $expected"
  else
    fail "$label = $actual, expected $expected"
  fi
}

# ── Git helper ──

git_init_repo() {
  git init -q
  git config user.email "fixture@test.local"
  git config user.name "fixture"
  [ -n "${1:-}" ] && git add -A && git commit -q -m "${1:-init}"
}

# ── Runners (never fail this script; return exit code for assertions) ──

run_integrate() {
  python3 "$INTEGRATE_DIR/apply.py" "$@" 2>&1
}

run_plan() {
  python3 "$INTEGRATE_DIR/plan.py" "$@" 2>&1
}

run_scan() {
  python3 "$INTEGRATE_DIR/scan.py" "$@" 2>&1
}
