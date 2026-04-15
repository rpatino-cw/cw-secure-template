# guards/collaboration.sh — Path traversal, write overwrite, teammate collision
# Sourced by guard.sh. Uses: FILE_PATH, TOOL_NAME

# --- Path traversal ---
if [[ "$FILE_PATH" == *".."* ]]; then
  echo "BLOCKED: Path traversal detected: $FILE_PATH" >&2
  echo "File paths must not contain '..' components." >&2
  exit 2
fi

# --- Block Write tool on existing files (must use Edit) ---
if [[ "$TOOL_NAME" == "Write" && -f "$FILE_PATH" ]]; then
  LINE_COUNT=$(wc -l < "$FILE_PATH" 2>/dev/null || echo "0")
  if [[ "$LINE_COUNT" -gt 10 ]]; then
    echo "BLOCKED: Cannot overwrite existing file $FILE_PATH ($LINE_COUNT lines)" >&2
    echo "Use Edit with targeted old_string/new_string instead of Write." >&2
    echo "Write is only for creating NEW files." >&2
    exit 2
  fi
fi

# --- Teammate collision detection ---
if [[ -n "$FILE_PATH" && -f "$FILE_PATH" ]]; then
  if git diff --name-only 2>/dev/null | grep -qF "$FILE_PATH" || \
     git diff --cached --name-only 2>/dev/null | grep -qF "$FILE_PATH"; then
    LAST_AUTHOR=$(git log -1 --format="%an" -- "$FILE_PATH" 2>/dev/null || echo "")
    LAST_TIME=$(git log -1 --format="%ar" -- "$FILE_PATH" 2>/dev/null || echo "")
    echo "WARNING: $FILE_PATH has uncommitted changes" >&2
    if [[ -n "$LAST_AUTHOR" ]]; then
      echo "Last modified by: $LAST_AUTHOR ($LAST_TIME)" >&2
    fi
    echo "Another teammate may be actively editing this file." >&2
    echo "Edit blocked — coordinate with your team or commit/stash their changes first." >&2
    exit 2
  fi
fi
