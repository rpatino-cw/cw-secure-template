# Presence Server — live team dashboard

A zero-dependency stdlib HTTP + SSE server that upgrades `team-dashboard.html`
from a 5-second polling snapshot into a real-time multiplayer view of your
team. When one teammate runs it, every other teammate who opens the dashboard
appears live — their current file, their room, and the second they stop
editing they fade out.

## Why this exists

The template already has `make dashboard` — generates a snapshot of
`team.json`, `rooms.json`, and `rooms/activity.md`, serves it statically,
polls every 5s. Works, but passive. You never *see* a teammate working;
you only see what was true at the last polling tick.

This server adds:

- **Live presence** — who's online right now, what file they're in, what room.
- **Heartbeat / TTL** — goes idle, drops silently after 30s.
- **Real-time push** — Server-Sent Events on `/api/stream`. No polling.
- **Event log** — guard triggers, pushes, gate runs — append-only to `events.jsonl`.
- **Backward compatible** — `/dashboard-data.json` returns the same payload
  `scripts/serve-dashboard.sh` produced, so the existing dashboard keeps working.

## Run it

```bash
make team-server          # starts on :4000
# (in another terminal)
open http://localhost:4000/team-dashboard.html
```

One person runs the server; everyone on the team opens that URL. On the same
LAN they see each other instantly. Remote teams can host `server.py` on any
box with a port — Fly.io, Railway, a VPS, or a Tailscale-exposed laptop.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/` | → `/team-dashboard.html` |
| `GET` | `/<file>` | Serve static from repo root |
| `GET` | `/dashboard-data.json` | Snapshot (same format `make dashboard` produced) |
| `GET` | `/api/team` | `team.json` |
| `GET` | `/api/rooms` | `rooms.json` |
| `GET` | `/api/presence` | Everyone online right now |
| `POST` | `/api/presence` | Heartbeat — `{user, file, room, state}` |
| `GET` | `/api/events?limit=50` | Recent events |
| `POST` | `/api/events` | Append `{type, ...}` event |
| `GET` | `/api/stream` | SSE stream of snapshot + every change |

## Wire it to Claude Code (optional)

`hooks/presence-hook.sh` is a PostToolUse hook. When any agent runs `Edit`
or `Write`, the hook POSTs a heartbeat with the file path + derived room.
Your teammates see the edit live in their dashboards.

Drop this into `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash server/hooks/presence-hook.sh" }
        ]
      }
    ]
  }
}
```

Env vars the hook reads:

- `DASHBOARD_URL` — server URL (default `http://localhost:4000`)
- `USER_ID` — who you are (default `$USER`)
- `ROOM_ID` — optional override; otherwise auto-derived from `rooms.json`

## Files

| File | Purpose |
|---|---|
| `server.py` | The server (stdlib only, ~250 lines) |
| `hooks/presence-hook.sh` | PostToolUse hook, fires heartbeat on every Edit/Write |
| `events.jsonl` | Append-only event log (runtime; gitignored) |

## Hosting for remote teams

The server is one file with no deps — trivially deployable:

- **Fly.io** — `fly launch` on this folder, set `PORT=8080`, done
- **Tailscale** — run on any node, share the tailnet IP with teammates
- **Your laptop** — if everyone's on the same LAN, zero setup beyond `make team-server`

## Compared to `make dashboard`

| | `make dashboard` (snapshot) | `make team-server` (live) |
|---|---|---|
| Deps | Python stdlib | Python stdlib |
| Data | Regenerated on each refresh | Streamed on every change |
| Latency | 5s polling | ~0ms SSE push |
| Presence | No | Yes |
| Multi-user view | No | Yes |
| Events log | No | `events.jsonl` |
| Port | 8090 | 4000 |

Both coexist — pick whichever fits the moment.
