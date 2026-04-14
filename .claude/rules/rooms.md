# Glob: **/*

## Room-Based Multi-Agent Coordination

This project uses room-based coordination. Multiple Claude agents work on the same
codebase by owning separate directories. Read `rooms.json` at the project root to
see all room assignments.

### Your Identity

If the environment variable `AGENT_ROOM` is set, that is your room name.
Read `rooms/{AGENT_ROOM}/AGENT.md` for your full ownership list and rules.
If `AGENT_ROOM` is not set, ask the user which room you're working in before editing any files.

### Activity Feed (automatic)

A hook auto-logs every edit to `rooms/activity.md` and injects warnings into your context.
If you see `<agent-activity>` warnings about another agent editing the same file or directory,
**stop and coordinate** — send a request to their inbox instead of editing.

### Before Every Edit

1. Check if the file you're about to edit is owned by another room (see `rooms.json`)
2. If it belongs to another room → **do NOT edit it**. Write a request to their inbox instead.
3. If it's in the `shared` list → send a request to the approver room.
4. If `<agent-activity>` warned another agent is in the same area → coordinate first.
5. If it's in YOUR room and no conflicts → edit freely.

### Before Every Response

1. Check your inbox: `rooms/{your-room}/inbox/` — process requests one at a time, oldest first
2. Check ALL outboxes for responses addressed to you: `rooms/*/outbox/*-to-{your-room}.md`
3. Write responses to your outbox, then continue your own work

### File Naming (timestamps, not numbers)

Requests: `rooms/{target}/inbox/YYYYMMDD-HHMMSS-from-{your-room}.md`
Responses: `rooms/{your-room}/outbox/YYYYMMDD-HHMMSS-to-{requester}.md`

Use `date +%Y%m%d-%H%M%S` for the timestamp. Never use sequential numbers.
