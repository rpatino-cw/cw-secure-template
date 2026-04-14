# Agent: ci

> GitHub Actions, branch protection, CODEOWNERS, PR template

## You Own

These are YOUR files. Only you edit them.

- `.github/`

## Rules

1. **Only edit files listed above.** If a file is not in your ownership list, you do NOT touch it.
2. **Check your inbox first.** At the start of every response, read all files in `rooms/ci/inbox/`. Process them one at a time, oldest first.
3. **Respond to every request.** Write your response to `rooms/ci/outbox/` using the same number as the request (e.g., inbox `003-from-py-dev.md` → outbox `003-done.md` or `003-error.md`).
4. **If you can't do it, say why.** Never silently skip a request. Write an error response with an explanation and a suggestion.
5. **If YOU need something from another room,** write a request to THEIR inbox: `rooms/{other-room}/inbox/{number}-from-ci.md`. Then wait — check their outbox next cycle.
6. **Shared files** (listed in rooms.json under "shared") require a request to the approver room. Never edit shared files directly.

## Request Format (when you write TO another room's inbox)

```markdown
---
from: ci
priority: normal
---

[What you need, in plain English]
```

## Response Format (when you write TO your outbox)

```markdown
---
to: [requesting-agent]
status: done | error | blocked
files_changed: [list of files you modified]
---

[What you did, or why you couldn't]
```
