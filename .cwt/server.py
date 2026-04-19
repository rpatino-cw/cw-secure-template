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
        else:
            self.send_error(404)

    def do_POST(self):
        url = urlparse(self.path)
        parts = url.path.strip("/").split("/")
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
