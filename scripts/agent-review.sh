#!/usr/bin/env bash
# agent-review.sh — AI code review before push
#
# Runs the code-reviewer agent against your uncommitted or unpushed changes.
# Blocks the push if the agent says "Changes Requested."
#
# Usage:
#   bash scripts/agent-review.sh          # review unpushed commits
#   make review                           # same thing
#
# Skip (emergency only):
#   SKIP_AGENT_REVIEW=1 git push          # bypass the agent review
#
# Requires: claude CLI installed and authenticated

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Skip check ──
if [ "${SKIP_AGENT_REVIEW:-}" = "1" ]; then
  echo -e "  ${YELLOW}[SKIP]${NC} Agent review bypassed (SKIP_AGENT_REVIEW=1)"
  exit 0
fi

# ── Check claude is available ──
if ! command -v claude &>/dev/null; then
  echo -e "  ${YELLOW}[SKIP]${NC} Agent review skipped — claude CLI not installed"
  exit 0
fi

# ── Get the diff to review ──
# Try unpushed commits first, fall back to staged changes
REMOTE_BRANCH=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
if [ -n "$REMOTE_BRANCH" ]; then
  DIFF=$(git diff "$REMOTE_BRANCH"...HEAD 2>/dev/null)
  DIFF_SOURCE="unpushed commits vs $REMOTE_BRANCH"
else
  DIFF=$(git diff HEAD~1 2>/dev/null || git diff --cached 2>/dev/null)
  DIFF_SOURCE="latest commit"
fi

# ── Skip if no changes ──
if [ -z "$DIFF" ]; then
  echo -e "  ${GREEN}[PASS]${NC} No changes to review"
  exit 0
fi

DIFF_LINES=$(echo "$DIFF" | wc -l | tr -d ' ')
DIFF_FILES=$(echo "$DIFF" | grep -c '^diff --git' || true)

echo -e "  ${DIM}Agent reviewing $DIFF_FILES file(s), $DIFF_LINES lines ($DIFF_SOURCE)...${NC}"

# ── Trim large diffs to avoid token limits ──
MAX_LINES=500
if [ "$DIFF_LINES" -gt "$MAX_LINES" ]; then
  DIFF=$(echo "$DIFF" | head -"$MAX_LINES")
  TRIMMED=true
else
  TRIMMED=false
fi

# ── Run the code-reviewer agent ──
REVIEW_PROMPT="Review this diff for security issues, quality problems, and convention violations.

Rules:
- APPROVED means the code is safe to push
- CHANGES REQUESTED means there are blocking issues that must be fixed
- Only request changes for real problems (secrets, injection, missing auth, dangerous functions)
- Don't request changes for style preferences or minor issues

Your FIRST line of output must be exactly one of:
VERDICT: APPROVED
VERDICT: CHANGES REQUESTED

Then explain your reasoning briefly.

$(if [ "$TRIMMED" = true ]; then echo "(Note: diff truncated to $MAX_LINES lines)"; fi)

\`\`\`diff
$DIFF
\`\`\`"

# Run claude in print mode with the code-reviewer agent
REVIEW_OUTPUT=$(echo "$REVIEW_PROMPT" | claude -p --model sonnet --max-budget-usd 0.05 2>/dev/null || echo "VERDICT: APPROVED
Agent review unavailable — allowing push.")

# ── Parse verdict ──
VERDICT_LINE=$(echo "$REVIEW_OUTPUT" | grep -m1 "^VERDICT:" || echo "VERDICT: APPROVED")

if echo "$VERDICT_LINE" | grep -qi "CHANGES REQUESTED"; then
  echo ""
  echo -e "  ${RED}${BOLD}AGENT REVIEW: Changes Requested${NC}"
  echo ""
  # Show the review (skip the verdict line, show the reasoning)
  echo "$REVIEW_OUTPUT" | grep -v "^VERDICT:" | while IFS= read -r line; do
    [ -n "$line" ] && echo -e "  ${DIM}$line${NC}"
  done
  echo ""
  echo -e "  ${BOLD}Fix the issues above, commit, and push again.${NC}"
  echo -e "  ${DIM}Emergency bypass: SKIP_AGENT_REVIEW=1 git push${NC}"
  echo ""
  exit 1
else
  echo -e "  ${GREEN}[PASS]${NC} Agent review: Approved"
  # Show brief reasoning if any
  REASON=$(echo "$REVIEW_OUTPUT" | grep -v "^VERDICT:" | head -2 | tr '\n' ' ' | xargs)
  if [ -n "$REASON" ]; then
    echo -e "  ${DIM}$REASON${NC}"
  fi
fi

exit 0
