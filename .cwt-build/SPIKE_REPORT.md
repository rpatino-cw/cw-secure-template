# CWT Phase 0 Spike — Report

**Date:** 2026-04-19
**Question:** Can a PreToolUse hook cleanly gate Claude's Edit/Write calls against an approved manifest?
**Verdict:** **VIABLE.** Proceed to Phase 1.

---

## What Was Built

| File | Purpose |
|------|---------|
| `.claude/hooks/PreToolUse/cwt-gate.sh` | The gate hook. Reads stdin JSON, checks target file against manifest, exits 0 or 2. |
| `.cwt/manifest-approved.json` | Demo manifest. Lists approved file paths + plan_id. |

## Test Matrix

| # | Scenario | Expected | Result |
|:-:|----------|----------|--------|
| 1 | `Bash` tool call | allow (hook skips non-Edit tools) | ✓ exit 0 |
| 2 | `Edit` on file listed in manifest | allow | ✓ exit 0 |
| 3 | `Edit` on file NOT in manifest | block with message | ✓ exit 2, clear stderr |
| 4 | `Edit` in project without any `.cwt/` dir | allow (opt-in) | ✓ exit 0 |

## What Works

1. **Structured denial.** Exit 2 + stderr message is visible to Claude and readable to the user. No silent failures.
2. **Opt-in by design.** No `.cwt/` = hook no-ops. Safe to drop into any repo.
3. **Repo-root detection walks up.** Works regardless of where the edit target lives.
4. **Plain bash + python3.** No new deps. Works on any macOS/Linux dev box.
5. **Clear bypass path.** Delete manifest = gate off. Not hidden, not magic.

## What Doesn't Work Yet / Caveats

1. **Manifest format is bare.** Only `files[]` is checked. A real plan needs: allowed *ops* (edit vs create vs delete), line-range limits, expiration. Phase 1 expands schema.
2. **No MultiEdit granularity.** Currently treats MultiEdit as atomic — blocks whole call if any target is unapproved. Could be finer.
3. **No feedback loop yet.** When blocked, Claude sees the message but there's no machine-readable "how to amend" — Phase 1 adds a structured hint.
4. **Hook not registered in settings.json.** Intentionally — don't auto-enable. Phase 1 adds `make cwt-enable` / `make cwt-disable`.
5. **No audit log.** Blocked attempts aren't logged. Phase 1 adds `.cwt/audit.log` for review.

## Drift Risk Flagged

The gate only sees the target file path, not the *content* of the diff. A malicious / drifting agent could still make unapproved semantic changes inside an approved file. Phase 2+ needs diff-scope checks (lines or symbols), not just file paths.

**Not a blocker for Phase 1.** Worth flagging now.

## To Enable Locally

```bash
# Register the hook in .claude/settings.json (not done automatically):
#   "hooks": {
#     "PreToolUse": [
#       { "matcher": "Edit|Write|MultiEdit",
#         "hooks": [{ "type": "command",
#                     "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/PreToolUse/cwt-gate.sh" }] }
#     ]
#   }

# Then restart Claude Code. From now on, edits outside .cwt/manifest-approved.json
# will be blocked with the gate message.
```

## Reproduce the Test

```bash
HOOK=~/dev/cw-secure-template/.claude/hooks/PreToolUse/cwt-gate.sh
echo '{"tool_name":"Edit","tool_input":{"file_path":"/Users/rpatino/dev/cw-secure-template/go/main.go"}}' | "$HOOK"
# Should exit 2 with a CWT PLAN GATE message on stderr
```

## Decision

**Proceed to Phase 1.** The gate primitive works. Build the dashboard + plan queue + approval UI on top of this foundation.
