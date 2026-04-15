#!/usr/bin/env bash
# repo-lint.sh — Validate repo-level hygiene after push
#
# Checks: LICENSE, OG tags, homepage URL, README links, stale files.
# Run: make repo-lint
# Also wired into post-push output (informational, never blocks).

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PASS=0
FAIL=0
WARN=0

ok()   { echo -e "  ${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; ((WARN++)); }

echo ""
echo "  Repo Lint"
echo "  ─────────"
echo ""

# ── LICENSE ──
if [ -f "$REPO_ROOT/LICENSE" ]; then
  ok "LICENSE file exists"
else
  fail "No LICENSE file — add MIT or Apache 2.0"
fi

# ── README ──
if [ -f "$REPO_ROOT/README.md" ]; then
  LINES=$(wc -l < "$REPO_ROOT/README.md" | tr -d ' ')
  if [ "$LINES" -le 150 ]; then
    ok "README.md ($LINES lines)"
  else
    warn "README.md is $LINES lines (target: under 150)"
  fi
else
  fail "No README.md"
fi

# ── OG Meta Tags (if docs/index.html exists) ──
INDEX="$REPO_ROOT/docs/index.html"
if [ -f "$INDEX" ]; then
  if grep -q 'og:title' "$INDEX"; then
    ok "OG title tag present"
  else
    fail "docs/index.html missing og:title meta tag"
  fi
  if grep -q 'og:description' "$INDEX"; then
    ok "OG description tag present"
  else
    fail "docs/index.html missing og:description meta tag"
  fi
  if grep -q 'og:image' "$INDEX"; then
    ok "OG image tag present"
  else
    warn "docs/index.html missing og:image meta tag — link previews won't have an image"
  fi
fi

# ── GitHub homepage (check via git remote) ──
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$REMOTE_URL" == *"github.com"* ]]; then
  # Extract owner/repo
  REPO_SLUG=$(echo "$REMOTE_URL" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
  if command -v gh &>/dev/null; then
    HOMEPAGE=$(gh api "repos/$REPO_SLUG" --jq '.homepage // ""' 2>/dev/null || echo "")
    if [ -n "$HOMEPAGE" ]; then
      ok "GitHub homepage set: $HOMEPAGE"
    else
      warn "GitHub homepage not set — run: gh repo edit --homepage \"URL\""
    fi
  fi
fi

# ── SECURITY.md ──
if [ -f "$REPO_ROOT/SECURITY.md" ]; then
  ok "SECURITY.md exists"
else
  warn "No SECURITY.md — add incident response template"
fi

# ── .gitignore covers secrets ──
if [ -f "$REPO_ROOT/.gitignore" ]; then
  MISSING=""
  for pattern in ".env" "*.pem" "*.key" "credentials.json"; do
    if ! grep -q "$pattern" "$REPO_ROOT/.gitignore" 2>/dev/null; then
      MISSING="$MISSING $pattern"
    fi
  done
  if [ -z "$MISSING" ]; then
    ok ".gitignore covers secret patterns"
  else
    fail ".gitignore missing:$MISSING"
  fi
fi

# ── Stale/orphan files ──
UNTRACKED=$(git ls-files --others --exclude-standard "$REPO_ROOT/docs/screenshots/" 2>/dev/null | head -5)
if [ -n "$UNTRACKED" ]; then
  warn "Untracked files in docs/screenshots/: $(echo "$UNTRACKED" | tr '\n' ' ')"
fi

# ── CLAUDE.md exists ──
if [ -f "$REPO_ROOT/CLAUDE.md" ]; then
  ok "CLAUDE.md exists"
else
  fail "No CLAUDE.md — security guardrails missing"
fi

# ── Summary ──
TOTAL=$((PASS + FAIL + WARN))
echo ""
echo "  ─────────"
echo -e "  ${PASS}/${TOTAL} passing"
[ "$FAIL" -gt 0 ] && echo -e "  ${RED}${FAIL} issues${NC}"
[ "$WARN" -gt 0 ] && echo -e "  ${YELLOW}${WARN} warnings${NC}"
echo ""

exit "$FAIL"
