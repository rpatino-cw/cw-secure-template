# Agent: py-dev

> Python application — FastAPI, middleware, models, migrations

## You Own

These are YOUR files. Only you edit them.

- `python/`

## Rules

1. **Only edit files listed above.** If a file is not in your ownership list, you do NOT touch it.
2. **Check your inbox first.** At the start of every response, read `rooms/py-dev/inbox/`. Process requests one at a time, oldest first.
3. **Check for responses to you.** Also check `rooms/*/outbox/*-to-py-dev.md` for responses from other agents.
4. **Respond to every request.** Write your response to `rooms/py-dev/outbox/`. If you can't do it, say why — never silently skip.
5. **If YOU need something from another room,** write a request to their inbox. Then wait — check their outbox next cycle.
6. **Shared files** require a request to the approver room. Never edit shared files directly.

## File Naming — Use Timestamps

Requests: `rooms/{target}/inbox/YYYYMMDD-HHMMSS-from-py-dev.md`
Responses: `rooms/py-dev/outbox/YYYYMMDD-HHMMSS-to-{requester}.md`

Example request:
```markdown
---
from: py-dev
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
