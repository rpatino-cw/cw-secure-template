#!/bin/bash
# new-project.sh — scaffold a fresh project from cw-secure-template
#
# Usage:
#   ./scripts/new-project.sh <project-name> [parent-dir]
#
# Examples:
#   ./scripts/new-project.sh my-app              → ~/dev/my-app
#   ./scripts/new-project.sh my-app ~/projects   → ~/projects/my-app
#
# Copies the current template state (minus local .cwt/ runtime + git history)
# into a new directory, initializes fresh git, and prints next steps.

set -euo pipefail

NAME="${1:-}"
PARENT="${2:-$HOME/dev}"

if [[ -z "$NAME" ]]; then
    echo "Usage: $0 <project-name> [parent-dir]"
    exit 1
fi

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$PARENT/$NAME"

if [[ -e "$DEST" ]]; then
    echo "Error: $DEST already exists."
    exit 1
fi

echo "==> Scaffolding $NAME from $SRC → $DEST"
mkdir -p "$DEST"

# Copy everything except these runtime/history paths
rsync -a \
    --exclude='.git/' \
    --exclude='.cwt/queue/' \
    --exclude='.cwt/port' \
    --exclude='.cwt/manifest-approved.json' \
    --exclude='.cwt/server.log' \
    --exclude='.cwt-build/' \
    --exclude='node_modules/' \
    --exclude='__pycache__/' \
    --exclude='.venv/' \
    --exclude='.pytest_cache/' \
    --exclude='*.pyc' \
    "$SRC/" "$DEST/"

# Reset the queue to empty state
mkdir -p "$DEST/.cwt/queue/pending" "$DEST/.cwt/queue/approved" "$DEST/.cwt/queue/rejected"

# Fresh git
cd "$DEST"
git init -q
git add -A
git commit -q -m "chore: scaffold $NAME from cw-secure-template" || true

echo ""
echo "==> Done."
echo ""
echo "Next steps:"
echo "  cd $DEST"
echo "  python3 .cwt/server.py       # boot the CWT dashboard"
echo "  claude                       # start Claude Code; /cwt-plan works here"
echo ""
echo "To pull upstream framework updates later:"
echo "  git remote add cwt $SRC"
echo "  make cwt-upgrade             # (once Phase 4 ships this target)"
