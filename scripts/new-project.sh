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
echo "  ✓ scaffolded $NAME at $DEST"
echo "  ✓ git initialized with first commit"
echo ""
# The rest of the "next steps" message is printed by the `cwt init` shell
# function after it cd's into the project. When new-project.sh is called
# directly (without the cwt wrapper), print a fallback here.
if [ -z "${CWT_INIT_WRAPPED:-}" ]; then
  echo "  Next:"
  echo "    cd $DEST"
  echo "    cwt up      # (or: python3 .cwt/server.py) — boot dashboard"
  echo "    claude      # start Claude Code"
  echo ""
fi
