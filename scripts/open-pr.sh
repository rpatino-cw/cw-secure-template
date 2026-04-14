#!/usr/bin/env bash
# open-pr.sh — Run all checks then open a PR to main
#
# Usage: make pr
#    or: bash scripts/open-pr.sh
#
# Runs the full check suite locally first. If everything passes,
# pushes the branch and opens a PR with a security checklist.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

# ── Preflight ──
if [ "$BRANCH" = "main" ]; then
  echo ""
  echo -e "  ${RED}You're on main.${NC} Create a branch first:"
  echo "    ${GREEN}make branch NAME=my-feature${NC}"
  echo ""
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo ""
  echo -e "  ${RED}GitHub CLI (gh) not installed.${NC}"
  echo "    ${GREEN}brew install gh && gh auth login${NC}"
  echo ""
  exit 1
fi

echo ""
echo -e "${BOLD}  Opening PR: $BRANCH → main${NC}"
echo ""

# ── Run all checks ──
echo -e "  ${DIM}Running checks before PR...${NC}"
echo ""

FAILED=0

# Tests
echo -e "  ${DIM}Tests...${NC}"
if [ -f go/go.mod ]; then
  (cd go && go test -race -count=1 ./... 2>&1 | tail -3) || FAILED=1
fi
if [ -f python/pyproject.toml ]; then
  (cd python && python -m pytest --tb=short -q 2>&1 | tail -3) || FAILED=1
fi

# Lint
echo -e "  ${DIM}Lint...${NC}"
if [ -f go/go.mod ]; then
  (cd go && golangci-lint run 2>&1 | tail -3) || FAILED=1
fi
if [ -f python/pyproject.toml ]; then
  (cd python && ruff check . 2>&1 | tail -3) || FAILED=1
fi

# Security
echo -e "  ${DIM}Security scan...${NC}"
SECRET_HITS=$(grep -rn --include="*.go" --include="*.py" -E "(password|secret|token|api_key)\s*[:=]\s*[\"'][^\"']{8,}" go/ python/ 2>/dev/null | grep -v "_test\." | grep -v ".example" | wc -l | tr -d ' ')
if [ "$SECRET_HITS" -gt 0 ]; then
  echo -e "  ${RED}[FAIL]${NC} $SECRET_HITS potential hardcoded secrets"
  FAILED=1
fi

# Room lint
if [ -f rooms.json ]; then
  echo -e "  ${DIM}Room config...${NC}"
  bash scripts/room-lint.sh || FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo ""
  echo -e "  ${RED}${BOLD}Checks failed. Fix issues before opening PR.${NC}"
  echo "    Run ${GREEN}make check${NC} for details."
  echo ""
  exit 1
fi

echo ""
echo -e "  ${GREEN}All checks passed.${NC}"
echo ""

# ── Push branch ──
echo -e "  ${DIM}Pushing $BRANCH...${NC}"
git push -u origin "$BRANCH" 2>&1 | tail -2

# ── Build PR body ──
COMMIT_COUNT=$(git rev-list --count main.."$BRANCH" 2>/dev/null || echo "?")
FILES_CHANGED=$(git diff --stat main..."$BRANCH" 2>/dev/null | tail -1 || echo "")

# ── Open PR ──
echo -e "  ${DIM}Opening pull request...${NC}"
echo ""

# Build PR body into a temp file (avoids heredoc quoting issues)
PR_BODY_FILE=$(mktemp)
cat > "$PR_BODY_FILE" << 'PREOF'
## Summary

PREOF
echo "Branch: \`$BRANCH\` → \`main\`" >> "$PR_BODY_FILE"
echo "Commits: $COMMIT_COUNT | $FILES_CHANGED" >> "$PR_BODY_FILE"
cat >> "$PR_BODY_FILE" << 'PREOF'

## Local checks passed

- [x] Tests
- [x] Lint
- [x] Security scan (no hardcoded secrets)
- [x] Room config lint

## Security checklist

- [ ] No secrets in code (env vars only)
- [ ] Auth on new endpoints (or DEV_MODE documented)
- [ ] Input validated with strict schemas
- [ ] Parameterized queries (no SQL concatenation)
- [ ] Error responses don't leak internals
- [ ] SECURITY LESSON comments on security decisions
- [ ] Tests added for new functionality
- [ ] `make check` passes locally

---
Generated with [Claude Code](https://claude.ai/code) using CW Secure Template
PREOF

PR_URL=$(gh pr create \
  --base main \
  --head "$BRANCH" \
  --title "$(git log -1 --format='%s')" \
  --body-file "$PR_BODY_FILE" 2>&1)

rm -f "$PR_BODY_FILE"

echo -e "  ${GREEN}${BOLD}PR opened:${NC} $PR_URL"
echo ""
echo -e "  ${DIM}CI will run automatically. Merge when all checks pass.${NC}"
echo ""
