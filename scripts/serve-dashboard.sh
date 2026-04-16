#!/usr/bin/env bash
# serve-dashboard.sh — Generate dashboard data snapshot and serve securely
#
# Usage: make dashboard
#
# Generates dashboard-data.json from project files, copies it + dashboard HTML
# into a temp directory, serves ONLY that directory on 127.0.0.1:8090.
# No source code, .env, or other project files are exposed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVE_DIR=$(mktemp -d)
trap "rm -rf $SERVE_DIR" EXIT

# ── Generate dashboard data ──
python3 -c "
import json, os, glob, datetime

repo = os.environ.get('REPO_ROOT', '.')

# Read team.json
team = {}
team_path = os.path.join(repo, 'team.json')
if os.path.isfile(team_path):
    with open(team_path) as f:
        team = json.load(f)

# Read rooms.json
rooms = {}
rooms_path = os.path.join(repo, 'rooms.json')
if os.path.isfile(rooms_path):
    with open(rooms_path) as f:
        rooms = json.load(f)

# Read activity log (last 50 lines)
activity = []
activity_path = os.path.join(repo, 'rooms', 'activity.md')
if os.path.isfile(activity_path):
    with open(activity_path) as f:
        lines = f.readlines()[-50:]
        activity = [l.strip() for l in lines if l.strip()]

# Count inbox requests per room
inbox_counts = {}
rooms_dir = os.path.join(repo, 'rooms')
if os.path.isdir(rooms_dir):
    for room_dir in glob.glob(os.path.join(rooms_dir, '*', 'inbox')):
        room_name = os.path.basename(os.path.dirname(room_dir))
        count = len(glob.glob(os.path.join(room_dir, '*.md')))
        if count > 0:
            inbox_counts[room_name] = count

# Read enforcement profile
profile = 'balanced'
profile_path = os.path.join(repo, '.enforcement-profile')
if os.path.isfile(profile_path):
    with open(profile_path) as f:
        profile = f.read().strip()

data = {
    'generated': datetime.datetime.now().isoformat(),
    'project': os.path.basename(repo),
    'team': team,
    'rooms': rooms,
    'activity': activity,
    'inbox_counts': inbox_counts,
    'profile': profile,
}

print(json.dumps(data, indent=2))
" > "$SERVE_DIR/dashboard-data.json"

# Copy dashboard HTML
cp "$REPO_ROOT/team-dashboard.html" "$SERVE_DIR/" 2>/dev/null || {
  echo "  Error: team-dashboard.html not found. Build it first."
  exit 1
}

echo ""
echo "  Dashboard ready at http://127.0.0.1:8090/team-dashboard.html"
echo "  Press Ctrl+C to stop."
echo ""

cd "$SERVE_DIR"
python3 -m http.server 8090 --bind 127.0.0.1
