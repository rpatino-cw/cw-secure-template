#!/usr/bin/env bash
set -euo pipefail

# Creates .claude/settings.local.json to override unsafe global defaults.
# This file takes precedence over both project and global settings.json,
# ensuring this repo's guards can't be bypassed by a permissive global config.

GREEN='\033[0;32m'
DIM='\033[2m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TARGET="$REPO_ROOT/.claude/settings.local.json"

if [ -f "$TARGET" ]; then
  echo -e "  ${GREEN}Already configured${NC} — .claude/settings.local.json exists."
  exit 0
fi

mkdir -p "$REPO_ROOT/.claude"

cat > "$TARGET" << 'SETTINGS'
{
  "permissions": {
    "defaultMode": "allowEdits"
  }
}
SETTINGS

echo ""
echo -e "  ${GREEN}Secure mode enabled.${NC}"
echo ""
echo "  Created .claude/settings.local.json"
echo "  → Overrides global bypassPermissions / autopilot settings"
echo "  → Claude Code will now respect this repo's ask-list and deny-list"
echo ""
echo -e "  ${DIM}This file is gitignored — each clone needs to run this once.${NC}"
echo ""
