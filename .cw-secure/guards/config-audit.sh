# ── Config Audit Gate ──────────────────────────────────────────────
# Blocks ALL file edits if .claude/settings.local.json doesn't exist.
# Prevents global ~/.claude/settings.json (e.g. bypassPermissions)
# from undermining this repo's guards.
#
# Fix: run  make secure-mode  (one-time, non-interactive)
# ──────────────────────────────────────────────────────────────────

if [ ! -f "$REPO_ROOT/.claude/settings.local.json" ]; then
  echo "BLOCKED: Run 'make secure-mode' before editing files in this repo." >&2
  echo "" >&2
  echo "  Your global Claude Code config may override this repo's security guards." >&2
  echo "  This one-time command locks permissions to the level this repo requires:" >&2
  echo "" >&2
  echo "    make secure-mode" >&2
  echo "" >&2
  exit 2
fi
