"""Page routes — server-rendered HTML pages.

These serve the dashboard and UI pages using Jinja2 templates.
No auth required for the welcome page (it's informational).
"""

import os
import json
from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse

router = APIRouter(tags=["pages"])

# Project context from MEMORY.md and environment
_project_root = Path(__file__).resolve().parent.parent.parent.parent


def _get_project_info() -> dict:
    """Read project context from .claude/MEMORY.md and environment."""
    info = {
        "name": "My App",
        "purpose": "An internal tool built with CW Secure Framework",
        "team": "your-team",
        "stack": "Python",
        "dev_mode": os.environ.get("DEV_MODE", "false").lower() == "true",
        "okta_configured": bool(os.environ.get("OKTA_ISSUER", "")),
    }

    # Try to read from MEMORY.md
    memory_file = _project_root / ".claude" / "MEMORY.md"
    if memory_file.exists():
        content = memory_file.read_text()
        for line in content.split("\n"):
            if line.startswith("- **Name:**"):
                info["name"] = line.split("**Name:**")[1].strip()
            elif line.startswith("- **Purpose:**"):
                info["purpose"] = line.split("**Purpose:**")[1].strip()
            elif line.startswith("- **Team:**"):
                info["team"] = line.split("**Team:**")[1].strip()

    # Check security posture
    info["guards"] = {
        "claude_md": (_project_root / "CLAUDE.md").exists(),
        "guard_sh": (_project_root / "scripts" / "guard.sh").exists(),
        "pre_commit": (_project_root / ".pre-commit-config.yaml").exists(),
        "ci": (_project_root / ".github" / "workflows" / "ci.yml").exists(),
        "gitignore": (_project_root / ".gitignore").exists(),
    }
    info["guard_count"] = sum(info["guards"].values())

    # Check rooms
    rooms_file = _project_root / "rooms.json"
    if rooms_file.exists():
        try:
            rooms = json.loads(rooms_file.read_text())
            info["rooms"] = list(rooms.get("rooms", {}).keys())
        except json.JSONDecodeError:
            info["rooms"] = []
    else:
        info["rooms"] = []

    return info


@router.get("/", response_class=HTMLResponse)
async def dashboard(request: Request):
    info = _get_project_info()
    return request.app.state.templates.TemplateResponse(
        "dashboard.html", {"request": request, "info": info}
    )
