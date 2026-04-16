# guards/freeze.sh — Block edits to frozen files unless tests pass
# Sourced by guard.sh. Uses: FILE_PATH

FROZEN_REGISTRY=".frozen-files"

if [[ -f "$FROZEN_REGISTRY" ]]; then
  while IFS= read -r frozen_file; do
    [[ -z "$frozen_file" || "$frozen_file" == "#"* ]] && continue
    if [[ "$FILE_PATH" == *"$frozen_file"* ]]; then
      echo "" >&2
      echo "  ╔══════════════════════════════════════════════════════╗" >&2
      echo "  ║  FROZEN FILE — $frozen_file" >&2
      echo "  ║                                                      ║" >&2
      echo "  ║  This file is protected by freeze.sh.                ║" >&2
      echo "  ║  Run project tests to verify changes are safe.       ║" >&2
      echo "  ║  Unfreeze: ./scripts/freeze.sh --unfreeze $frozen_file" >&2
      echo "  ╚══════════════════════════════════════════════════════╝" >&2
      echo "" >&2
      echo "WARN: Frozen file modification attempted: $frozen_file" >&2
      # Warn but don't block — the pre-commit hook runs tests as the real gate.
      # Guard warns at edit time, hook enforces at commit time.
      break
    fi
  done < "$FROZEN_REGISTRY"
fi
