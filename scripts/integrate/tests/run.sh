#!/usr/bin/env bash
# CW Secure Template — Integration test harness
#
# Runs each fixture in scripts/integrate/tests/fixtures/ in isolation.
# Each fixture exits 0 (pass) or non-zero (fail). Harness aggregates.
#
# Usage:
#   bash scripts/integrate/tests/run.sh            # all fixtures
#   bash scripts/integrate/tests/run.sh 03         # match by number/name
#   make integrate-test                            # via Makefile

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
FIXTURES_DIR="$HERE/fixtures"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

FILTER="${1:-}"
PASS=0
FAIL=0
FAIL_NAMES=()

echo -e "${BOLD}CW Secure — integration test suite${NC}"
echo "==================================="
echo ""

for fixture in "$FIXTURES_DIR"/*.sh; do
  name="$(basename "$fixture" .sh)"
  if [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]]; then
    continue
  fi

  if bash "$fixture"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAIL_NAMES+=("$name")
  fi
  echo ""
done

TOTAL=$((PASS + FAIL))
echo "==================================="
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}✓ ALL PASS${NC}  $PASS/$TOTAL"
  exit 0
else
  echo -e "${RED}${BOLD}✗ FAILED${NC}  $FAIL/$TOTAL"
  for n in "${FAIL_NAMES[@]}"; do
    echo -e "    ${RED}✗${NC} $n"
  done
  exit 1
fi
