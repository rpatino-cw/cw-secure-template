# Glob: **/*

## Room-Based Multi-Agent Coordination

This project uses room-based coordination. Multiple Claude agents work on the same
codebase by owning separate directories. Read `rooms.json` at the project root to
see all room assignments.

### Before Every Edit

1. Check if the file you're about to edit is owned by another room (see `rooms.json` → `rooms.{name}.owns`)
2. If it belongs to another room → **do NOT edit it**. Write a request to that room's inbox instead: `rooms/{owner}/inbox/{number}-from-{your-room}.md`
3. If it's in the `shared` list → send a request to the approver room listed in `rooms.json`
4. If it's in YOUR room → edit freely

### Before Every Response

1. Check your inbox: `rooms/{your-room}/inbox/`
2. Process requests **one at a time**, oldest first
3. Write responses to `rooms/{your-room}/outbox/`
4. Then continue your own work

### Your Identity

If the environment variable `AGENT_ROOM` is set, that is your room name.
Read `rooms/{AGENT_ROOM}/AGENT.md` for your full ownership list and rules.

If `AGENT_ROOM` is not set, ask the user which room you're working in before editing any files.
