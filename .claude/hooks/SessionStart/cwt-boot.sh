#!/bin/bash
# cwt-boot.sh — SessionStart hook
# Starts .cwt/server.py in the background if not already running.
# Silent if the server is already up. Emits a one-line status to stderr on boot.

set -uo pipefail

# Only run if the project has CWT installed
[[ -d .cwt && -f .cwt/server.py ]] || exit 0

# Already running?
if [[ -f .cwt/port ]]; then
    PORT=$(cat .cwt/port 2>/dev/null)
    if [[ -n "$PORT" ]] && curl -sf -o /dev/null "http://127.0.0.1:$PORT/api/manifest" 2>/dev/null; then
        exit 0
    fi
    # Stale port file — clean up
    rm -f .cwt/port
fi

# Boot in background, detached from this hook's process group
nohup python3 .cwt/server.py > .cwt/server.log 2>&1 < /dev/null &
disown 2>/dev/null || true

# Brief wait for port file to appear
for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -f .cwt/port ]] && break
    sleep 0.2
done

if [[ -f .cwt/port ]]; then
    PORT=$(cat .cwt/port)
    echo "[cwt] server booted → http://127.0.0.1:$PORT" >&2
else
    echo "[cwt] server boot timed out; check .cwt/server.log" >&2
fi

exit 0
