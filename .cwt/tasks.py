"""
CWT tasks — Phase 5 MVP.

Reads task DAG JSON files from .cwt/tasks/*.json, validates depends_on
edges, returns topologically-ordered tasks with status.

Each task file shape:

    {
      "id": "T-1",
      "title": "short description",
      "owner": "room-name" | null,
      "status": "todo" | "in-progress" | "done" | "blocked",
      "depends_on": ["T-0"]
    }

Stdlib only. Used by /api/tasks and `make cwt-team`.
"""

import json
from pathlib import Path

TASKS_DIR = Path(__file__).resolve().parent / "tasks"
QUEUE_DIR = Path(__file__).resolve().parent / "queue"

VALID_STATUS = {"todo", "in-progress", "done", "blocked"}


def _plan_status_by_id():
    """Return {plan_id: status} by scanning .cwt/queue/{approved,rejected,pending}/."""
    out = {}
    for status in ("approved", "rejected", "pending"):
        d = QUEUE_DIR / status
        if not d.exists():
            continue
        for f in d.glob("*.json"):
            try:
                data = json.loads(f.read_text())
                pid = data.get("id") or f.stem
                out[pid] = status
            except Exception:
                continue
    return out


def _apply_plan_links(tasks):
    """Override task status based on linked plan status. Manual 'done' wins."""
    plan_status = _plan_status_by_id()
    for t in tasks:
        if not isinstance(t, dict):
            continue
        pid = t.get("plan_id")
        if not pid or pid not in plan_status:
            continue
        t["_linked_plan"] = {"id": pid, "status": plan_status[pid]}
        # Don't demote done
        if t.get("status") == "done":
            continue
        ps = plan_status[pid]
        if ps == "approved":
            t["status"] = "in-progress"
        elif ps == "rejected":
            t["status"] = "blocked"
    return tasks


def load_tasks():
    """Read every *.json in .cwt/tasks/. Returns list of task dicts."""
    tasks = []
    if not TASKS_DIR.exists():
        return tasks
    for f in sorted(TASKS_DIR.glob("*.json")):
        try:
            data = json.loads(f.read_text())
        except Exception as e:
            tasks.append({"id": f.stem, "_error": f"parse error: {e}"})
            continue
        if isinstance(data, list):
            tasks.extend(data)
        else:
            tasks.append(data)
    return tasks


def validate(tasks):
    """Return list of errors: missing deps, cycles, duplicate ids, bad status."""
    errors = []
    ids = set()
    for t in tasks:
        if not isinstance(t, dict) or "id" not in t:
            errors.append("task missing id")
            continue
        if t["id"] in ids:
            errors.append(f"duplicate id: {t['id']}")
        ids.add(t["id"])
        if t.get("status") and t["status"] not in VALID_STATUS:
            errors.append(f"{t['id']}: bad status '{t['status']}'")
    for t in tasks:
        for dep in t.get("depends_on", []) or []:
            if dep not in ids:
                errors.append(f"{t['id']}: unknown dep '{dep}'")
    return errors


def topo_order(tasks):
    """Kahn-style topo sort. Returns (ordered_ids, cycle_ids_or_None)."""
    by_id = {t["id"]: t for t in tasks if isinstance(t, dict) and "id" in t}
    indeg = {tid: 0 for tid in by_id}
    for t in by_id.values():
        for dep in t.get("depends_on", []) or []:
            if dep in by_id:
                indeg[t["id"]] += 1
    ready = [tid for tid, d in indeg.items() if d == 0]
    order = []
    while ready:
        ready.sort()
        tid = ready.pop(0)
        order.append(tid)
        for other in by_id.values():
            if tid in (other.get("depends_on") or []):
                indeg[other["id"]] -= 1
                if indeg[other["id"]] == 0:
                    ready.append(other["id"])
    if len(order) < len(by_id):
        cycle = [tid for tid in by_id if tid not in order]
        return order, cycle
    return order, None


def summary():
    """Return dict suitable for /api/tasks: ordered tasks + counts + errors.

    Status priority: manual 'done' > linked plan status > manual status.
    """
    tasks = load_tasks()
    errors = validate(tasks)
    tasks = _apply_plan_links(tasks)
    order, cycle = topo_order(tasks)
    by_id = {t["id"]: t for t in tasks if isinstance(t, dict) and "id" in t}
    ordered = [by_id[i] for i in order if i in by_id]
    counts = {s: 0 for s in VALID_STATUS}
    for t in ordered:
        s = t.get("status", "todo")
        if s in counts:
            counts[s] += 1
    return {
        "tasks": ordered,
        "counts": counts,
        "total": len(ordered),
        "errors": errors,
        "cycle": cycle,
    }
