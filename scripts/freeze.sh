#!/bin/bash
# freeze.sh — 3-layer file protection: git tag + pre-commit test gate + header comment
#
# Usage:
#   ./scripts/freeze.sh <file> [tag-name] [test-command]
#
# Examples:
#   ./scripts/freeze.sh src/parser.js parser-v1.0 "npm test"
#   ./scripts/freeze.sh go/middleware/auth.go auth-v2.0 "go test ./..."
#   ./scripts/freeze.sh python/src/main.py api-v1.0 "pytest"
#
# What it does:
#   1. Tags current commit as {tag-name}-frozen
#   2. Adds the file to .frozen-files (read by pre-commit hook)
#   3. Prepends a FROZEN header comment to the file
#
# To unfreeze:
#   ./scripts/freeze.sh --unfreeze <file>

set -euo pipefail

FROZEN_REGISTRY=".frozen-files"

# ── Unfreeze mode ──
if [[ "${1:-}" == "--unfreeze" ]]; then
  FILE="${2:?Usage: freeze.sh --unfreeze <file>}"
  if [[ -f "$FROZEN_REGISTRY" ]]; then
    grep -v "^${FILE}$" "$FROZEN_REGISTRY" > "${FROZEN_REGISTRY}.tmp" || true
    mv "${FROZEN_REGISTRY}.tmp" "$FROZEN_REGISTRY"
    echo "Unfrozen: $FILE (removed from $FROZEN_REGISTRY)"
    echo "Note: header comment and git tag are preserved for history."
  else
    echo "No frozen files registry found."
  fi
  exit 0
fi

# ── Freeze mode ──
FILE="${1:?Usage: freeze.sh <file> [tag-name] [test-command]}"
TAG_NAME="${2:-$(basename "$FILE" | sed 's/\.[^.]*$//')}-v1.0"
TEST_CMD="${3:-}"

if [[ ! -f "$FILE" ]]; then
  echo "Error: File not found: $FILE" >&2
  exit 1
fi

# Layer 1: Git tag
TAG="${TAG_NAME}-frozen"
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "Tag $TAG already exists — skipping tag creation."
else
  git tag "$TAG" -m "Frozen: $FILE — verified and protected. Restore: git checkout $TAG -- $FILE"
  echo "Layer 1: Tagged as $TAG"
fi

# Layer 2: Add to frozen registry (used by pre-commit hook)
touch "$FROZEN_REGISTRY"
if ! grep -qx "$FILE" "$FROZEN_REGISTRY" 2>/dev/null; then
  echo "$FILE" >> "$FROZEN_REGISTRY"
  echo "Layer 2: Added $FILE to $FROZEN_REGISTRY"
else
  echo "Layer 2: $FILE already in $FROZEN_REGISTRY"
fi

# Layer 3: Prepend FROZEN header (if not already present)
if ! head -3 "$FILE" | grep -q "FROZEN"; then
  EXT="${FILE##*.}"
  case "$EXT" in
    py)    CMT="#" ;;
    go)    CMT="//" ;;
    js|ts) CMT="//" ;;
    sh)    CMT="#" ;;
    *)     CMT="#" ;;
  esac

  HEADER="${CMT} ════════════════════════════════════════════════════════════
${CMT} FROZEN ${TAG_NAME} (tag: ${TAG})
${CMT} PROTECTED: Do not modify without running tests.
${CMT} Restore: git checkout ${TAG} -- ${FILE}
${CMT} ════════════════════════════════════════════════════════════
"
  # Preserve shebang if present
  FIRST_LINE=$(head -1 "$FILE")
  if [[ "$FIRST_LINE" == "#!"* ]]; then
    TEMP=$(mktemp)
    echo "$FIRST_LINE" > "$TEMP"
    echo "$HEADER" >> "$TEMP"
    tail -n +2 "$FILE" >> "$TEMP"
    mv "$TEMP" "$FILE"
  else
    TEMP=$(mktemp)
    echo "$HEADER" > "$TEMP"
    cat "$FILE" >> "$TEMP"
    mv "$TEMP" "$FILE"
  fi
  echo "Layer 3: Added FROZEN header to $FILE"
else
  echo "Layer 3: FROZEN header already present in $FILE"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  File frozen: $FILE"
echo "║  Tag: $TAG"
echo "║  Registry: $FROZEN_REGISTRY"
if [[ -n "$TEST_CMD" ]]; then
echo "║  Tests: $TEST_CMD"
fi
echo "║"
echo "║  To restore:  git checkout $TAG -- $FILE"
echo "║  To unfreeze: ./scripts/freeze.sh --unfreeze $FILE"
echo "╚══════════════════════════════════════════════════════╝"
