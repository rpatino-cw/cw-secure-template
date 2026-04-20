#!/usr/bin/env python3
"""
CWT new-project launcher — global landing server.

Flow:
  1. User runs `cwt new`, which starts this server and opens the landing page.
  2. User types a description, hits Send.
  3. POST /api/suggest returns 3 architecture candidates from Gemini
     (or a single generic-project fallback if Gemini is unavailable).
  4. User picks one.
  5. POST /api/scaffold runs scripts/new-project.sh <name>, boots the new project's
     .cwt/server.py, opens a Terminal with `claude`, pipes /cwt-plan <description>
     — and polls the new project's /api/health until ready, then returns its URL.
  6. Landing page redirects the browser to that URL.

Stdlib only — no external deps.
"""

import json
import os
import re
import socket
import subprocess
import sys
import time
import urllib.request
import urllib.error
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
TEMPLATE_ROOT = HERE.parent

# Global-state paths (live in user home, not in any single project)
GLOBAL_DIR = Path.home() / ".cwt-global"
PORT_FILE = GLOBAL_DIR / "port"

# Reach into the template's .cwt dir to reuse the gemini module
sys.path.insert(0, str(TEMPLATE_ROOT / ".cwt"))
try:
    import gemini as _gemini
except Exception:
    _gemini = None

LANDING_HTML = TEMPLATE_ROOT / ".cwt" / "new-landing.html"
NEW_PROJECT_SCRIPT = TEMPLATE_ROOT / "scripts" / "new-project.sh"
DEFAULT_DEST = Path.home() / "dev"


# ── helpers ──

def _pick_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def _unique_name(base):
    """If ~/dev/<base> exists, try <base>-2, <base>-3, ... up to 20."""
    for i in range(1, 21):
        candidate = base if i == 1 else f"{base}-{i}"
        if not (DEFAULT_DEST / candidate).exists():
            return candidate
    return f"{base}-{int(time.time())}"


def _fallback_architectures(description):
    """Return one generic architecture when Gemini is unavailable."""
    name = _gemini.slug_fallback(description) if _gemini else "new-project"
    return [{
        "label": "Generic Python project",
        "why": "A general-purpose scaffold — Claude will refine it from your description.",
        "stack": "Python (matches template's default)",
        "suggested_name": name,
    }]


def _run_scaffold(name):
    """Invoke scripts/new-project.sh <name>. Returns (ok, dest_path, error)."""
    try:
        r = subprocess.run(
            ["bash", str(NEW_PROJECT_SCRIPT), name],
            capture_output=True,
            timeout=60,
            env={**os.environ, "CWT_INIT_WRAPPED": "1"},
        )
    except Exception as e:
        return False, None, f"scaffold failed: {e}"
    if r.returncode != 0:
        return False, None, (r.stderr.decode(errors="replace") or r.stdout.decode(errors="replace"))[:400]
    return True, DEFAULT_DEST / name, None


def _boot_project_server(project_dir):
    """Start the new project's .cwt/server.py in the background. Wait for port."""
    log_path = project_dir / ".cwt" / "server.log"
    try:
        subprocess.Popen(
            ["python3", str(project_dir / ".cwt" / "server.py")],
            stdout=open(log_path, "ab"),
            stderr=subprocess.STDOUT,
            cwd=str(project_dir),
            start_new_session=True,
        )
    except Exception as e:
        return None, f"boot failed: {e}"
    port_file = project_dir / ".cwt" / "port"
    for _ in range(50):  # ~5s total
        if port_file.exists():
            try:
                return int(port_file.read_text().strip()), None
            except Exception:
                pass
        time.sleep(0.1)
    return None, "server did not write port file in time"


def _send_prompt_to_claude(project_dir, description, arch_label=None):
    """Open a new Terminal tab, run `claude` in project_dir, pipe /cwt-plan after delay."""
    if sys.platform != "darwin":
        return {"ok": False, "error": "auto-launch only on macOS currently"}
    if arch_label:
        plan_text = f"{description} — target architecture: {arch_label}"
    else:
        plan_text = description
    safe = plan_text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ").strip()
    cmd = f"cd {project_dir} && claude"
    script = (
        'tell application "Terminal"\n'
        '  activate\n'
        f'  set newTab to do script "{cmd}"\n'
        '  delay 4\n'
        f'  do script "/cwt-plan {safe}" in newTab\n'
        'end tell'
    )
    try:
        r = subprocess.run(["osascript", "-e", script], capture_output=True, timeout=10)
        if r.returncode == 0:
            return {"ok": True}
        return {"ok": False, "error": r.stderr.decode(errors="replace")[:200]}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def _wait_health(port, timeout_s=8):
    """Poll http://127.0.0.1:<port>/api/health until it answers."""
    deadline = time.time() + timeout_s
    url = f"http://127.0.0.1:{port}/api/health"
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1) as r:
                if r.status == 200:
                    return True
        except Exception:
            time.sleep(0.25)
    return False


# ── HTTP handlers ──

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def _send(self, status, body, content_type="application/json"):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        elif isinstance(body, str):
            body = body.encode()
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path in ("/", "/index.html"):
            try:
                html = LANDING_HTML.read_bytes()
                return self._send(200, html, "text/html; charset=utf-8")
            except Exception as e:
                return self._send(500, {"error": f"landing page missing: {e}"})
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        url = urlparse(self.path)
        length = int(self.headers.get("Content-Length", "0") or 0)
        raw = self.rfile.read(length) if length > 0 else b"{}"
        try:
            payload = json.loads(raw.decode() or "{}")
        except Exception:
            payload = {}

        if url.path == "/api/suggest":
            desc = (payload.get("description") or "").strip()
            if not desc:
                return self._send(400, {"error": "description required"})
            if _gemini and _gemini.is_available():
                archs = _gemini.suggest_architectures(desc)
                if archs:
                    return self._send(200, {"ok": True, "architectures": archs, "source": "gemini"})
            return self._send(200, {
                "ok": True,
                "architectures": _fallback_architectures(desc),
                "source": "fallback",
            })

        if url.path == "/api/scaffold":
            desc = (payload.get("description") or "").strip()
            arch = payload.get("arch") or {}
            name = str(arch.get("suggested_name", "")).strip()
            arch_label = str(arch.get("label", "")).strip() or None
            if not desc:
                return self._send(400, {"error": "description required"})
            if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,39}", name):
                # Gemini gave us something weird — regenerate from description
                if _gemini:
                    name = _gemini.slug_fallback(desc)
                else:
                    name = "new-project"
            name = _unique_name(name)

            ok, dest, err = _run_scaffold(name)
            if not ok:
                return self._send(500, {"error": f"scaffold failed: {err}"})

            port, boot_err = _boot_project_server(dest)
            if not port:
                return self._send(500, {"error": f"boot failed: {boot_err}", "dest": str(dest)})

            launched = _send_prompt_to_claude(dest, desc, arch_label)
            _wait_health(port, timeout_s=4)

            return self._send(200, {
                "ok": True,
                "name": name,
                "dest": str(dest),
                "dashboard_url": f"http://127.0.0.1:{port}/",
                "app_maker_launched": launched.get("ok", False),
            })

        return self._send(404, {"error": "not found"})


# ── main ──

def main():
    GLOBAL_DIR.mkdir(exist_ok=True)
    if not LANDING_HTML.exists():
        print(f"error: landing page missing at {LANDING_HTML}", file=sys.stderr)
        sys.exit(1)
    port = _pick_port()
    PORT_FILE.write_text(str(port))
    httpd = HTTPServer(("127.0.0.1", port), Handler)
    url = f"http://127.0.0.1:{port}/"
    print(f"cwt new — landing page: {url}")
    if "--open" in sys.argv:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\ncwt new server stopped")
        PORT_FILE.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
