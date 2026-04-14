# Glob: **/*

## Collaboration — Anti-Overwrite, Small Edits, Conflict Awareness

These rules apply to EVERY file. They prevent the #1 vibe coding problem: Claude destroying existing code.

### Edit Discipline
- **ALWAYS use Edit (targeted old_string/new_string) for existing files**
- **NEVER use Write to overwrite an existing file** unless the user explicitly says "rewrite this file"
- Keep edits SMALL — change the specific lines that need changing, not the whole file
- If a change touches more than 50 lines, stop and confirm with the user first
- Never remove code that isn't directly related to the current task

### Before Touching Any File
1. Check `git status` — if the file has uncommitted changes, WARN the user before editing
2. Check `git log -1 --format="%an %ar" -- <file>` — if someone else changed it recently, mention it
3. If the file was modified in the last hour by a different author, ASK before editing

### Branch Awareness
- Check what branch you're on before making changes
- If on `main`, suggest creating a feature branch first
- Never edit files that have merge conflicts — resolve conflicts first

### Teammate Safety
- If a file has unstaged changes, someone may be actively working on it — warn before editing
- Prefer adding new files over modifying shared files when possible
- When adding to an existing file, append — don't reorganize what's already there unless asked

### What This Prevents
- "Claude rewrote my whole file" — Edit only, targeted changes
- "Claude broke my teammate's work" — git status check before every edit
- "Claude deleted my function" — no removing code unrelated to the task
- "Claude merged into main" — branch awareness, suggest feature branches
