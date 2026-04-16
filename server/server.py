#!/usr/bin/env python3
"""
cw-secure-template · presence server
Stdlib-only HTTP + SSE server. Makes the team dashboard live — your teammates
appear the moment they open it, their current file appears as they edit, and
every guard trigger / push event streams into the activity view.

Run:
    make team-server              # port 4000 by default
    PORT=8090 python3 server.py   # or direct

Drop-in upgrade for `make dashboard` (snapshot mode):
    - Reads team.json / rooms.json from repo root (same files the snapshot uses)
    - Generates /dashboard-data.json on demand (same payload as serve-dashboard.sh)
    - Adds /api/presence, /api/events, /api/stream on top

Endpoints:
    GET  /                        → /team-dashboard.html
    GET  /<file>                  → static from repo root
    GET  /dashboard-data.json     → live snapshot (same format serve-dashboard.sh produced)
    GET  /api/team                → team.json
    GET  /api/rooms               → rooms.json
    GET  /api/presence            → [{user, file, room, state, last_seen}, …]
    POST /api/presence            → heartbeat — body: {user, file, room, state}
    GET  /api/events?limit=N      → last N events (default 50)
    POST /api/events              → append event — body: {type, ...}
    GET  /api/stream              → SSE: snapshot + every live change

Design:
    Presence TTL = 30s. Clients heartbeat every 8-10s.
    Events persist as JSONL in server/events.jsonl (gitignored).
    SSE pushes on every presence-update, presence-leave, and event.
    CORS open — this is internal team tooling.
"""

import datetime
import glob
import http.server
import json
import os
import queue
import sys
import threading
import time
from pathlib import Path
from urllib.parse import parse_qs, urlparse


# ========== PATHS ==========
HERE = Path(__file__).parent.resolve()
REPO = HERE.parent                        # cw-secure-template/
EVENTS_FILE = HERE / "events.jsonl"       # server-local state (gitignored)
TEAM_FILE = REPO / "team.json"            # existing repo file
ROOMS_FILE = REPO / "rooms.json"          # existing repo file
ACTIVITY_FILE = REPO / "rooms" / "activity.md"
PROFILE_FILE = REPO / ".enforcement-profile"


# ========== STATE ==========
presence = {}            # user_id → {user, file, room, state, last_seen, started}
events_cache = []        # in-memory recent events (bounded by EVENTS_CAP)
subscribers = []         # [queue.Queue, …] one per SSE client
state_lock = threading.Lock()

PRESENCE_TTL = 30
EVENTS_CAP = 500


# ========== EVENT LOG ==========
def load_events():
    global events_cache
    if not EVENTS_FILE.exists():
        return
    with EVENTS_FILE.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events_cache.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    if len(events_cache) > EVENTS_CAP:
        events_cache = events_cache[-EVENTS_CAP:]


def append_event(event):
    events_cache.append(event)
    if len(events_cache) > EVENTS_CAP:
        events_cache.pop(0)
    try:
        with EVENTS_FILE.open("a") as f:
            f.write(json.dumps(event) + "\n")
    except OSError as e:
        print(f"[warn] couldn't persist event: {e}", file=sys.stderr)
    broadcast({"type": "event", "payload": event})


# ========== PRESENCE ==========
def cleanup_presence():
    now = time.time()
    dropped = []
    with state_lock:
        for uid in list(presence.keys()):
            if now - presence[uid]["last_seen"] > PRESENCE_TTL:
                dropped.append(uid)
                del presence[uid]
    for uid in dropped:
        broadcast({"type": "presence-leave", "user": uid})


def background_cleanup():
    while True:
        time.sleep(5)
        try:
            cleanup_presence()
        except Exception as e:
            print(f"[warn] cleanup error: {e}", file=sys.stderr)


# ========== BROADCAST ==========
def broadcast(msg):
    wire = f"data: {json.dumps(msg)}\n\n".encode()
    dead = []
    for q in list(subscribers):
        try:
            q.put_nowait(wire)
        except queue.Full:
            dead.append(q)
    for q in dead:
        if q in subscribers:
            subscribers.remove(q)


# ========== DASHBOARD SNAPSHOT ==========
def build_dashboard_snapshot():
    """
    Same payload shape as scripts/serve-dashboard.sh produced — so the existing
    team-dashboard.html's fetch('dashboard-data.json') keeps working without
    changes. Generated on demand, always fresh.
    """
    team = {}
    if TEAM_FILE.exists():
        try:
            team = json.loads(TEAM_FILE.read_text())
        except json.JSONDecodeError:
            team = {}

    rooms = {}
    if ROOMS_FILE.exists():
        try:
            rooms = json.loads(ROOMS_FILE.read_text())
        except json.JSONDecodeError:
            rooms = {}

    activity = []
    if ACTIVITY_FILE.exists():
        try:
            lines = ACTIVITY_FILE.read_text().splitlines()[-50:]
            activity = [l.strip() for l in lines if l.strip()]
        except OSError:
            pass

    inbox_counts = {}
    rooms_dir = REPO / "rooms"
    if rooms_dir.is_dir():
        for room_dir in glob.glob(str(rooms_dir / "*" / "inbox")):
            room_name = Path(room_dir).parent.name
            count = len(glob.glob(str(Path(room_dir) / "*.md")))
            if count > 0:
                inbox_counts[room_name] = count

    profile = "balanced"
    if PROFILE_FILE.exists():
        try:
            profile = PROFILE_FILE.read_text().strip() or "balanced"
        except OSError:
            pass

    return {
        "generated": datetime.datetime.now().isoformat(),
        "project": REPO.name,
        "team": team,
        "rooms": rooms,
        "activity": activity,
        "inbox_counts": inbox_counts,
        "profile": profile,
    }


# ========== HANDLER ==========
class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(REPO), **kwargs)

    def log_message(self, fmt, *args):
        if "/api/stream" in self.path or "/api/presence" in self.path:
            return
        super().log_message(fmt, *args)

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        p = urlparse(self.path)
        route = p.path

        if route == "/":
            self.send_response(302)
            self.send_header("Location", "/team-dashboard.html")
            self.end_headers()
            return

        if route == "/dashboard-data.json":
            return self._json(build_dashboard_snapshot())

        if route == "/api/team":
            return self._serve_json_file(TEAM_FILE)

        if route == "/api/rooms":
            return self._serve_json_file(ROOMS_FILE)

        if route == "/api/presence":
            cleanup_presence()
            with state_lock:
                return self._json(list(presence.values()))

        if route == "/api/events":
            q = parse_qs(p.query)
            try:
                limit = max(1, min(500, int(q.get("limit", ["50"])[0])))
            except ValueError:
                limit = 50
            return self._json(events_cache[-limit:])

        if route == "/api/stream":
            return self._handle_sse()

        super().do_GET()

    def _serve_json_file(self, path):
        if not path.exists():
            return self._json({"error": f"{path.name} missing"}, 404)
        try:
            return self._json(json.loads(path.read_text()))
        except json.JSONDecodeError as e:
            return self._json({"error": f"bad json in {path.name}: {e}"}, 500)

    def do_POST(self):
        p = urlparse(self.path)
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        try:
            data = json.loads(body) if body else {}
        except json.JSONDecodeError:
            return self._json({"error": "bad json"}, 400)

        if p.path == "/api/presence":
            user = (data.get("user") or "").strip()
            if not user:
                return self._json({"error": "user required"}, 400)
            now = time.time()
            with state_lock:
                prev = presence.get(user, {})
                presence[user] = {
                    "user": user,
                    "file": data.get("file", ""),
                    "room": data.get("room", ""),
                    "state": data.get("state", "active"),
                    "last_seen": now,
                    "started": prev.get("started", now),
                }
                payload = dict(presence[user])
            broadcast({"type": "presence-update", "user": user, "payload": payload})
            return self._json({"ok": True, "ttl": PRESENCE_TTL})

        if p.path == "/api/events":
            evt = dict(data)
            evt["ts"] = evt.get("ts") or int(time.time() * 1000)
            append_event(evt)
            return self._json({"ok": True})

        return self._json({"error": "not found"}, 404)

    def _handle_sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache, no-transform")
        self.send_header("Connection", "keep-alive")
        self.send_header("X-Accel-Buffering", "no")
        self._cors()
        self.end_headers()

        q = queue.Queue(maxsize=200)
        subscribers.append(q)

        try:
            with state_lock:
                snapshot = {
                    "type": "snapshot",
                    "presence": list(presence.values()),
                    "events": events_cache[-20:],
                    "server_time": int(time.time() * 1000),
                }
            self.wfile.write(f"data: {json.dumps(snapshot)}\n\n".encode())
            self.wfile.flush()

            while True:
                try:
                    msg = q.get(timeout=15)
                    self.wfile.write(msg)
                    self.wfile.flush()
                except queue.Empty:
                    self.wfile.write(b": ping\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            if q in subscribers:
                subscribers.remove(q)


def main():
    port = int(os.environ.get("PORT", 4000))
    # Safe default: bind to loopback only. Opt into LAN exposure with BIND=0.0.0.0.
    bind = os.environ.get("BIND", "127.0.0.1")

    load_events()
    threading.Thread(target=background_cleanup, daemon=True).start()

    srv = http.server.ThreadingHTTPServer((bind, port), Handler)
    print("cw-secure-template · presence server")
    print(f"  listening   http://{bind}:{port}")
    print(f"  dashboard   http://localhost:{port}/team-dashboard.html")
    print(f"  snapshot    /dashboard-data.json (same format as make dashboard)")
    print(f"  presence    /api/presence  /api/stream  /api/events")
    print(f"  TTL={PRESENCE_TTL}s · heartbeat every {PRESENCE_TTL // 3}s recommended")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[shutting down]")
        srv.shutdown()


if __name__ == "__main__":
    main()
