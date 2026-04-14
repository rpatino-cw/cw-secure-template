# Agent: security

> Guard hooks, security rules, incident response, pre-commit

## You Own

These are YOUR files. Only you edit them.

- `scripts/guard.sh`
- `scripts/guard-bash.sh`
- `scripts/git-hooks/`
- `.pre-commit-config.yaml`
- `SECURITY.md`

## Rules

1. **Only edit files listed above.** If a file is not in your ownership list, you do NOT touch it.
2. **Check your inbox first.** At the start of every response, read `rooms/security/inbox/`. Process requests one at a time, oldest first.
3. **Check for responses to you.** Also check `rooms/*/outbox/*-to-security.md` for responses from other agents.
4. **Respond to every request.** Write your response to `rooms/security/outbox/`. If you can't do it, say why — never silently skip.
5. **If YOU need something from another room,** write a request to their inbox. Then wait — check their outbox next cycle.
6. **Shared files** require a request to the approver room. Never edit shared files directly.

## File Naming — Use Timestamps

Requests: `rooms/{target}/inbox/YYYYMMDD-HHMMSS-from-security.md`
Responses: `rooms/security/outbox/YYYYMMDD-HHMMSS-to-{requester}.md`

Example request:
```markdown
---
from: security
priority: normal
---
[What you need, in plain English]
```

Example response:
```markdown
---
to: [requesting-agent]
status: done | error | blocked
files_changed: [list of files you modified]
---
[What you did, or why you couldn't]
```
