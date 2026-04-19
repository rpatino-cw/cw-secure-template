---
description: Turn a feature request into a plan queued for GUI approval. Claude drafts the plan JSON, writes it to .cwt/queue/pending/, and STOPS — does not execute until the user approves in the CWT dashboard.
---

# /cwt-plan — Draft a plan, don't implement

You are in **plan-only** mode for this turn. The user has asked you to write code, but CWT requires plans to be reviewed and approved in a GUI before any edit happens.

## Your Job

1. **Read the user's ask** (the text after `/cwt-plan`). That is the feature they want.
2. **Analyze the codebase** to determine which files need to change. Use:
   - `rooms.json` — which room owns which paths
   - `.claude/rules/*.md` — layering rules (routes / services / models / config)
   - Existing code structure as precedent
3. **Draft a plan JSON** matching this schema:

```json
{
  "id": "P-YYYYMMDD-HHMMSS",
  "created_at": "ISO-8601 UTC timestamp",
  "prompt": "the user's original ask, verbatim",
  "summary": "one sentence — what this plan ships",
  "targets": [
    {
      "file": "path/relative/to/repo",
      "op": "create | edit | delete",
      "justification": "one sentence — WHY this file. Reference the specific rule or pattern that puts code here."
    }
  ],
  "status": "pending"
}
```

4. **Write the plan** to `.cwt/queue/pending/P-YYYYMMDD-HHMMSS.json` using `date +%Y%m%d-%H%M%S` for the id suffix.
5. **Do NOT edit any source files.** The PreToolUse hook would block you anyway, but don't even try — this is plan mode.
6. **Report** to the user:
   - Plan id
   - 1-sentence summary
   - Count of targets
   - Dashboard URL (read from `.cwt/port` → `http://127.0.0.1:{port}`)
   - "Approve in dashboard, then ask me to implement."

## Rules

- **Justifications must cite a specific rule.** "Routes layer per rules/routes.md" beats "seemed like a good place." The whole point is explaining the design.
- **No speculative files.** If you're unsure a file is needed, leave it out. User can amend the plan.
- **Use the existing room ownership.** If a target file is owned by a room the user isn't in, flag it — it may need a cross-room request.
- **Honor the dependency direction** (routes → services → repositories → models). Plans that skip layers fail review.
- **One plan per ask.** If the user's request spans unrelated features, ask them to split it.

## When to Refuse

- User asks to `/cwt-plan` edits to `.claude/`, `scripts/guard*`, or other guardrail files → refuse, explain these are protected.
- User asks to `/cwt-plan` removing the CWT system itself → refuse, suggest `rm .cwt/manifest-approved.json` as the kill switch.

## Example Output

> **Plan queued: P-20260419-114523**
> "Add /healthz/db endpoint" · 3 targets
> Dashboard: http://127.0.0.1:54388
> Approve in dashboard, then ask me to implement.
