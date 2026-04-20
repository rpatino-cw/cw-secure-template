#!/usr/bin/env python3
"""
CWT server — plan queue + approval gate dashboard.

Stdlib only. No deps. Run: python3 .cwt/server.py
Uses ephemeral port, writes it to .cwt/port for clients to discover.
"""

import json
import os
import socket
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parent
QUEUE = ROOT / "queue"
MANIFEST = ROOT / "manifest-approved.json"
HTML = ROOT / "cwt.html"
PORT_FILE = ROOT / "port"

sys.path.insert(0, str(ROOT))
try:
    from rater import score_plan  # Phase 2 conformance rater
except Exception:
    score_plan = None
try:
    from tasks import summary as tasks_summary  # Phase 5 task DAG
except Exception:
    tasks_summary = None
try:
    from graph import build_graph  # Phase 3 import graph
except Exception:
    build_graph = None
try:
    import gemini as _gemini  # Plain-English plan summaries
except Exception:
    _gemini = None


def list_plans():
    """Return all plans across pending/approved/rejected."""
    out = []
    for status in ("pending", "approved", "rejected"):
        d = QUEUE / status
        if not d.exists():
            continue
        for f in sorted(d.glob("*.json")):
            try:
                data = json.loads(f.read_text())
                data["_status"] = status
                data["_path"] = str(f.relative_to(ROOT))
                out.append(data)
            except Exception as e:
                out.append({"id": f.stem, "_status": status, "_error": str(e)})
    return out


def rebuild_manifest():
    """Aggregate all approved plan targets into manifest-approved.json."""
    files = []
    plan_ids = []
    for f in sorted((QUEUE / "approved").glob("*.json")):
        try:
            data = json.loads(f.read_text())
            plan_ids.append(data.get("id", f.stem))
            for t in data.get("targets", []):
                fp = t.get("file") if isinstance(t, dict) else t
                if fp and fp not in files:
                    files.append(fp)
            if score_plan is not None:
                try:
                    data["ratings"] = score_plan(data)
                    f.write_text(json.dumps(data, indent=2))
                except Exception as e:
                    data["ratings"] = {"error": str(e)}
        except Exception:
            continue
    manifest = {
        "plan_id": ",".join(plan_ids) if plan_ids else "(none approved)",
        "files": files,
        "summary": f"Aggregated from {len(plan_ids)} approved plan(s)",
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2))
    return manifest


def _find_plan_file(plan_id):
    """Locate a plan JSON across pending/approved/rejected queues."""
    if not plan_id or "/" in plan_id or ".." in plan_id:
        return None
    for status in ("pending", "approved", "rejected"):
        f = QUEUE / status / f"{plan_id}.json"
        if f.exists():
            return f
    return None


def _explain_plan_cached(plan_id):
    """Return {ok, text|error, cached}. Caches result in plan JSON under plain_english."""
    f = _find_plan_file(plan_id)
    if not f:
        return {"ok": False, "error": "plan not found"}
    try:
        data = json.loads(f.read_text())
    except Exception as e:
        return {"ok": False, "error": f"plan unreadable: {e}"}
    existing = data.get("plain_english")
    if existing and isinstance(existing, str) and existing.strip():
        return {"ok": True, "text": existing, "cached": True}
    if _gemini is None or not _gemini.is_available():
        return {"ok": False, "error": "gemini unavailable", "setup_hint": "Set GEMINI_API_KEY in ~/.config/keys/global.env"}
    text = _gemini.explain_plan(data)
    if not text:
        return {"ok": False, "error": "gemini returned no text"}
    data["plain_english"] = text
    try:
        f.write_text(json.dumps(data, indent=2))
    except Exception:
        pass  # still return the text even if we couldn't cache
    return {"ok": True, "text": text, "cached": False}


def _send_prompt(text):
    """Open a new terminal, start `claude`, then feed it a /cwt-plan <text> line.

    macOS: AppleScript `do script` runs `claude`, then after a delay sends the
    /cwt-plan command as shell input — since claude has taken over the tty,
    that text becomes claude's stdin. No clipboard, no keystroke simulation.

    Non-macOS: falls back to spawning a terminal with a command that auto-types
    after a sleep (less reliable; users on Linux may need to paste manually).
    """
    import subprocess
    import shutil
    import sys as _sys
    project = str(ROOT.parent)
    safe_text = str(text or "").replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").strip()
    if not safe_text:
        return {"ok": False, "error": "empty prompt"}
    cmd_str = f"cd {project} && claude"
    plan_line = f"/cwt-plan {safe_text}"
    if _sys.platform == "darwin" and shutil.which("osascript"):
        # Open new Terminal tab running claude, wait 3s for boot, send the /cwt-plan line
        script = (
            'tell application "Terminal"\n'
            '  activate\n'
            f'  set newTab to do script "{cmd_str}"\n'
            '  delay 3\n'
            f'  do script "{plan_line}" in newTab\n'
            'end tell'
        )
        try:
            r = subprocess.run(["osascript", "-e", script], capture_output=True, timeout=8)
            if r.returncode == 0:
                return {"ok": True, "method": "osascript", "prompt": plan_line}
            return {"ok": False, "error": r.stderr.decode(errors="replace")[:200], "prompt": plan_line}
        except Exception as e:
            return {"ok": False, "error": str(e), "prompt": plan_line}
    return {"ok": False, "error": "auto-send only supported on macOS right now", "prompt": plan_line}


def _launch_claude():
    """Open a new terminal tab running `claude` in the project directory.

    Returns dict with {ok, method, cmd} on success, {ok:false, error, cmd} on failure.
    The `cmd` field is always returned so the frontend can fall back to
    copy-to-clipboard when spawn fails (non-macOS, osascript denied, etc.).
    """
    import subprocess
    import shutil
    import sys as _sys
    project = str(ROOT.parent)
    cmd_str = f"cd {project} && claude"
    # macOS via osascript -> Terminal.app
    if _sys.platform == "darwin" and shutil.which("osascript"):
        script = f'tell application "Terminal" to do script "{cmd_str}"'
        try:
            r = subprocess.run(["osascript", "-e", script], capture_output=True, timeout=5)
            if r.returncode == 0:
                # Activate Terminal so the new window comes forward
                subprocess.run(["osascript", "-e", 'tell application "Terminal" to activate'],
                               capture_output=True, timeout=2)
                return {"ok": True, "method": "osascript", "cmd": cmd_str}
            return {"ok": False, "error": r.stderr.decode(errors="replace")[:200], "cmd": cmd_str}
        except Exception as e:
            return {"ok": False, "error": str(e), "cmd": cmd_str}
    # Linux — try common terminal emulators
    for term in ("x-terminal-emulator", "gnome-terminal", "konsole", "xterm"):
        if shutil.which(term):
            try:
                subprocess.Popen([term, "-e", "bash", "-c", f"{cmd_str}; exec bash"])
                return {"ok": True, "method": term, "cmd": cmd_str}
            except Exception as e:
                return {"ok": False, "error": str(e), "cmd": cmd_str}
    return {"ok": False, "error": "no terminal emulator available", "cmd": cmd_str}


def move_plan(plan_id, from_status, to_status):
    src = QUEUE / from_status / f"{plan_id}.json"
    if not src.exists():
        return None, f"plan {plan_id} not in {from_status}"
    data = json.loads(src.read_text())
    data["status"] = to_status
    dst = QUEUE / to_status / f"{plan_id}.json"
    dst.write_text(json.dumps(data, indent=2))
    src.unlink()
    rebuild_manifest()
    return data, None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # silence default stderr log spam
        pass

    def _send_json(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)

    def _send_html(self, path):
        try:
            body = path.read_bytes()
        except FileNotFoundError:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path in ("/", "/index.html"):
            self._send_html(HTML)
        elif url.path == "/api/plans":
            self._send_json(200, {"plans": list_plans()})
        elif url.path == "/api/manifest":
            try:
                self._send_json(200, json.loads(MANIFEST.read_text()))
            except Exception:
                self._send_json(200, {"files": [], "plan_id": "(none)"})
        elif url.path == "/api/health":
            try:
                port = int(PORT_FILE.read_text().strip())
            except Exception:
                port = 0
            self._send_json(200, {"status": "ok", "port": port})
        elif url.path == "/api/tasks":
            if tasks_summary is None:
                self._send_json(200, {"tasks": [], "counts": {}, "total": 0, "errors": ["tasks module unavailable"]})
            else:
                try:
                    self._send_json(200, tasks_summary())
                except Exception as e:
                    self._send_json(200, {"tasks": [], "counts": {}, "total": 0, "errors": [str(e)]})
        elif url.path == "/api/graph":
            if build_graph is None:
                self._send_json(200, {"nodes": [], "edges": [], "stats": {}})
            else:
                try:
                    self._send_json(200, build_graph())
                except Exception as e:
                    self._send_json(200, {"nodes": [], "edges": [], "stats": {}, "error": str(e)})
        else:
            self.send_error(404)

    def do_POST(self):
        url = urlparse(self.path)
        parts = url.path.strip("/").split("/")
        # /api/launch-claude — spawn Claude Code in a new terminal tab
        if url.path == "/api/launch-claude":
            return self._send_json(200, _launch_claude())
        # /api/explain-plan/{id} — plain-English summary via Gemini, cached in plan JSON
        if url.path.startswith("/api/explain-plan/"):
            plan_id = url.path[len("/api/explain-plan/"):]
            return self._send_json(200, _explain_plan_cached(plan_id))
        # /api/send-prompt — spawn Claude Code + auto-type a /cwt-plan line
        if url.path == "/api/send-prompt":
            length = int(self.headers.get("Content-Length", "0") or 0)
            body = self.rfile.read(length) if length > 0 else b"{}"
            try:
                payload = json.loads(body.decode() or "{}")
            except Exception:
                payload = {}
            text = payload.get("text", "")
            return self._send_json(200, _send_prompt(text))
        # /api/plans/{id}/approve | /api/plans/{id}/reject
        if len(parts) == 4 and parts[0] == "api" and parts[1] == "plans":
            plan_id, action = parts[2], parts[3]
            if action == "approve":
                data, err = move_plan(plan_id, "pending", "approved")
            elif action == "reject":
                data, err = move_plan(plan_id, "pending", "rejected")
            else:
                return self._send_json(400, {"error": "unknown action"})
            if err:
                return self._send_json(404, {"error": err})
            return self._send_json(200, {"ok": True, "plan": data})
        self.send_error(404)


def pick_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def main():
    QUEUE.mkdir(exist_ok=True)
    for sub in ("pending", "approved", "rejected"):
        (QUEUE / sub).mkdir(exist_ok=True)

    # Rebuild manifest from whatever is currently in approved/
    # This overwrites the demo manifest with the real aggregated one.
    rebuild_manifest()

    port = pick_port()
    PORT_FILE.write_text(str(port))

    httpd = HTTPServer(("127.0.0.1", port), Handler)
    url = f"http://127.0.0.1:{port}/"
    print(f"CWT server ready → {url}")
    print(f"(port written to {PORT_FILE.relative_to(ROOT.parent)})")

    if "--open" in sys.argv:
        webbrowser.open(url)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nCWT server stopped")
        PORT_FILE.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
