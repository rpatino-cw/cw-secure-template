"""Path constants and configuration for the personal knowledge base."""

from pathlib import Path
from datetime import datetime, timezone

# ── Paths ──────────────────────────────────────────────────────────────
# .claude/memory/scripts/config.py → project root is 3 levels up
MEMORY_DIR = Path(__file__).resolve().parent.parent  # .claude/memory/
PROJECT_ROOT = MEMORY_DIR.parent.parent              # project root
DAILY_DIR = PROJECT_ROOT / "daily"
KNOWLEDGE_DIR = PROJECT_ROOT / "knowledge"
CONCEPTS_DIR = KNOWLEDGE_DIR / "concepts"
CONNECTIONS_DIR = KNOWLEDGE_DIR / "connections"
QA_DIR = KNOWLEDGE_DIR / "qa"
REPORTS_DIR = PROJECT_ROOT / "reports"
SCRIPTS_DIR = MEMORY_DIR / "scripts"
HOOKS_DIR = MEMORY_DIR / "hooks"
AGENTS_FILE = MEMORY_DIR / "AGENTS.md"

INDEX_FILE = KNOWLEDGE_DIR / "index.md"
LOG_FILE = KNOWLEDGE_DIR / "log.md"
STATE_FILE = SCRIPTS_DIR / "state.json"

# For backwards compat with scripts that use ROOT_DIR
ROOT_DIR = PROJECT_ROOT

# ── Timezone ───────────────────────────────────────────────────────────
TIMEZONE = "America/Chicago"


def now_iso() -> str:
    """Current time in ISO 8601 format."""
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def today_iso() -> str:
    """Current date in ISO 8601 format."""
    return datetime.now(timezone.utc).astimezone().strftime("%Y-%m-%d")
