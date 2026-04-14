#!/usr/bin/env bash
# create-branch.sh — Create a feature branch from main
#
# Usage: make branch NAME=add-login
#    or: bash scripts/create-branch.sh <branch-name>
#
# Naming: auto-prefixes with the room name if AGENT_ROOM is set.
# Example: AGENT_ROOM=go + NAME=add-auth → go/add-auth

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

NAME="${1:-}"

if [ -z "$NAME" ]; then
  echo ""
  echo "  Usage: make branch NAME=my-feature"
  echo ""
  echo "  Examples:"
  echo "    make branch NAME=add-login"
  echo "    make branch NAME=fix-auth-bug"
  echo "    make branch NAME=update-payments"
  echo ""
  exit 1
fi

# Clean the branch name
NAME=$(echo "$NAME" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9\-]//g')

# Prefix with room name if in agent mode
if [ -n "${AGENT_ROOM:-}" ]; then
  BRANCH="${AGENT_ROOM}/${NAME}"
else
  BRANCH="feature/${NAME}"
fi

# Check we're on main or at least up to date
CURRENT=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [ "$CURRENT" != "main" ]; then
  echo -e "  ${YELLOW}Note:${NC} You're on '$CURRENT', not main."
  echo -e "  ${DIM}Creating branch from current HEAD.${NC}"
fi

# Fetch latest main
git fetch origin main --quiet 2>/dev/null || true

# Create and switch to branch
if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  echo -e "  Branch '${BOLD}$BRANCH${NC}' already exists. Switching to it."
  git checkout "$BRANCH"
else
  git checkout -b "$BRANCH"
  echo ""
  echo -e "  ${GREEN}Created branch:${NC} ${BOLD}$BRANCH${NC}"
fi

echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "    1. Write code — Claude handles the rest"
echo "    2. Commit:  ${GREEN}git add . && git commit -m \"your message\"${NC}"
echo "    3. Push:    ${GREEN}git push -u origin $BRANCH${NC}"
echo "    4. Open PR: ${GREEN}make pr${NC}"
echo ""
