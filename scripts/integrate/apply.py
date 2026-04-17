#!/usr/bin/env python3
"""
CW Secure Template — Apply Phase

Executes the integration plan against a target app. Writes files,
runs merges, creates backup tag + working branch, rolls back on error,
writes a manifest for future upgrade/remove.

Usage:
    python3 apply.py /path/to/target [--force] [--scope=backend/] [--include-node]
    python3 apply.py /path/to/target --dry-run         # alias for plan.py

Design: plan.py builds the action list; apply.py consumes it. One source
of truth (portability.yaml). No duplication with adopt.sh — this retires it.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
TEMPLATE_ROOT = HERE.parent.parent


# ───────────────────────── tty helpers ─────────────────────────

RED    = "\033[0;31m"
GREEN  = "\033[0;32m"
YELLOW = "\033[1;33m"
BOLD   = "\033[1m"
DIM    = "\033[2m"
NC     = "\033[0m"


def info(msg: str)  -> None: print(f"  {GREEN}{msg}{NC}")
def warn(msg: str)  -> None: print(f"  {YELLOW}{msg}{NC}")
def error(msg: str) -> None: print(f"  {RED}{msg}{NC}")


def run(cmd: list, cwd: str | None = None, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, check=check)


def _sha(path: Path) -> str:
    if not path.exists() or not path.is_file():
        return ""
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


# ───────────────────────── Safety rails ─────────────────────────

def preflight(plan: dict, force: bool) -> None:
    target = Path(plan["target"])
    safety = plan["safety"]
    git = plan["scan"]["git"]

    if safety.get("require_git_repo") and not git["is_git_repo"]:
        if force:
            warn(f"Target is not a git repo — continuing without safety rails (--force).")
        else:
            raise SystemExit(f"{RED}Target is not a git repo. Run `git init` in {target}, or pass --force.{NC}")

    if safety.get("require_clean_tree") and git["is_git_repo"] and git["dirty"]:
        if force:
            warn("Working tree is dirty — continuing with --force. Rollback may lose uncommitted work.")
        else:
            raise SystemExit(f"{RED}Working tree is dirty on {git['branch']}. Commit/stash first, or pass --force.{NC}")


def create_backup(plan: dict) -> dict:
    """Create backup tag + working branch. Returns state for rollback()."""
    target = plan["target"]
    git = plan["scan"]["git"]
    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    state = {"tag": None, "branch": None, "original_branch": None}

    if not git["is_git_repo"]:
        return state

    state["original_branch"] = git["branch"]

    if plan["safety"].get("create_backup_tag"):
        tag = f"cw-integrate-backup-{ts}"
        run(["git", "tag", tag], cwd=target)
        state["tag"] = tag
        info(f"Backup tag created: {tag}")

    if plan["safety"].get("create_working_branch"):
        branch = f"cw-integrate-{ts}"
        run(["git", "checkout", "-b", branch], cwd=target)
        state["branch"] = branch
        info(f"Working branch: {branch}")

    return state


def rollback(target: str, state: dict) -> None:
    if not state.get("tag"):
        warn("No backup tag — cannot roll back automatically.")
        return
    try:
        run(["git", "reset", "--hard", state["tag"]], cwd=target)
        if state.get("original_branch") and state.get("branch"):
            run(["git", "checkout", state["original_branch"]], cwd=target)
            run(["git", "branch", "-D", state["branch"]], cwd=target)
        info(f"Rolled back to {state['tag']}.")
    except subprocess.CalledProcessError as e:
        error(f"Rollback failed: {e.stderr}")


# ───────────────────────── Action executors ─────────────────────────

def _apply_rewrites(text: str, rewrites: list) -> str:
    for r in rewrites or []:
        text = text.replace(r["from"], r["to"])
    return text


def _strip_lines(text: str, patterns: list) -> str:
    if not patterns:
        return text
    lines = text.splitlines(keepends=True)
    out = []
    for line in lines:
        if any(pat in line for pat in patterns):
            continue
        out.append(line)
    return "".join(out)


def _substitute(text: str, placeholders: dict) -> str:
    for key, val in (placeholders or {}).items():
        text = text.replace(f"{{{{{key}}}}}", str(val) if val is not None else "")
    return text


def act_copy(action: dict, target: Path, manifest_entry: dict) -> None:
    src = TEMPLATE_ROOT / action["source"]
    dest = target / action["dest"]

    if not src.exists():
        raise FileNotFoundError(f"Template source missing: {src}")

    dest.parent.mkdir(parents=True, exist_ok=True)
    content = src.read_text(errors="ignore")
    content = _apply_rewrites(content, action.get("rewrites"))
    content = _strip_lines(content, action.get("strip_lines"))

    dest.write_text(content)
    if src.suffix in (".sh", ".py"):
        os.chmod(dest, 0o755)

    manifest_entry["hash"] = _sha(dest)
    info(f"COPY    {action['dest']}")


def act_merge_settings_json(action: dict, target: Path, manifest_entry: dict) -> None:
    """Delegate to existing adopt-merge-settings.py (already battle-tested)."""
    helper = TEMPLATE_ROOT / action["merge_helper"]
    dest = target / action["dest"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    run(["python3", str(helper), str(dest), ".cw-secure"], cwd=str(target))
    manifest_entry["hash"] = _sha(dest)
    info(f"MERGE   {action['dest']}  (via {action['merge_helper']})")


def act_merge_precommit(action: dict, target: Path, manifest_entry: dict) -> None:
    """Merge template's pre-commit repos into target's YAML, deduped by repo URL."""
    src = TEMPLATE_ROOT / action["source"]
    dest = target / action["dest"]

    try:
        import yaml
    except ImportError:
        raise SystemExit("PyYAML required for .pre-commit-config.yaml merge. pip install pyyaml")

    src_cfg = yaml.safe_load(src.read_text())
    if dest.exists():
        dst_cfg = yaml.safe_load(dest.read_text()) or {}
    else:
        dst_cfg = {"repos": []}

    dst_repos = dst_cfg.setdefault("repos", [])
    seen = {r.get("repo") for r in dst_repos if isinstance(r, dict)}
    added = 0
    for repo in (src_cfg.get("repos") or []):
        if repo.get("repo") not in seen:
            dst_repos.append(repo)
            added += 1

    dest.write_text(yaml.safe_dump(dst_cfg, sort_keys=False))
    manifest_entry["hash"] = _sha(dest)
    manifest_entry["repos_added"] = added
    info(f"MERGE   {action['dest']}  (+{added} repos)")


def act_merge(action: dict, target: Path, manifest_entry: dict) -> None:
    if action.get("merge_helper"):
        return act_merge_settings_json(action, target, manifest_entry)
    if action.get("merge_strategy") == "yaml_repos_append":
        return act_merge_precommit(action, target, manifest_entry)
    raise NotImplementedError(f"No merge strategy for: {action['dest']}")


def act_append(action: dict, target: Path, manifest_entry: dict) -> None:
    """Marker-based idempotent append. Re-run replaces the marked section."""
    dest = target / action["dest"]
    dest.parent.mkdir(parents=True, exist_ok=True)

    markers = action.get("markers") or []
    if len(markers) != 2:
        raise ValueError(f"append needs 2 markers, got {markers}")
    start_key, end_key = markers

    # Resolve marker tokens (loaded from portability.yaml)
    marker_tokens = action.get("marker_tokens") or {}
    start_token = marker_tokens.get(start_key, start_key)
    end_token = marker_tokens.get(end_key, end_key)

    # Build the section body
    patterns = action.get("patterns")
    src = action.get("source")
    if patterns:
        body = "\n".join(patterns)
    elif src:
        body = (TEMPLATE_ROOT / src).read_text()
    else:
        raise ValueError(f"append needs source OR patterns: {action['dest']}")

    # Substitute placeholders in body
    body = _substitute(body, action.get("placeholders"))

    new_section = f"\n{start_token}\n{body.rstrip()}\n{end_token}\n"

    if dest.exists():
        existing = dest.read_text()
        pattern = re.compile(
            re.escape(start_token) + r".*?" + re.escape(end_token) + r"\n?",
            re.DOTALL,
        )
        if pattern.search(existing):
            updated = pattern.sub(new_section.lstrip("\n").rstrip("\n") + "\n", existing)
            dest.write_text(updated)
            info(f"APPEND  {action['dest']}  (replaced existing section)")
        else:
            dest.write_text(existing.rstrip() + "\n" + new_section)
            info(f"APPEND  {action['dest']}  (new section)")
    else:
        header = _substitute(action.get("header") or "", action.get("placeholders"))
        dest.write_text(header + new_section)
        info(f"APPEND  {action['dest']}  (file created)")

    manifest_entry["hash"] = _sha(dest)
    manifest_entry["markers"] = [start_token, end_token]


def act_generate(action: dict, target: Path, manifest_entry: dict) -> None:
    """Recursive copy with placeholder substitution. Skips files if source missing."""
    src_rel = action.get("source")
    if not src_rel:
        warn(f"GEN     {action['dest']}  (no template source — wiring snippet only)")
        manifest_entry["snippet_only"] = True
        return

    src = TEMPLATE_ROOT / src_rel
    dest = target / action["dest"]

    if not src.exists():
        warn(f"GEN     {action['dest']}  (template source missing: {src_rel})")
        return

    dest.mkdir(parents=True, exist_ok=True)
    count = 0
    for f in src.rglob("*"):
        if not f.is_file():
            continue
        rel = f.relative_to(src)
        out = dest / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        content = f.read_text(errors="ignore")
        content = _substitute(content, action.get("placeholders"))
        out.write_text(content)
        count += 1

    manifest_entry["files_generated"] = count
    info(f"GEN     {action['dest']}  ({count} files)")


EXECUTORS = {
    "copy":     act_copy,
    "merge":    act_merge,
    "append":   act_append,
    "generate": act_generate,
}


# ───────────────────────── Manifest ─────────────────────────

def write_manifest(plan: dict, manifest: dict) -> None:
    target = Path(plan["target"])
    path = target / plan["manifest_path"]

    # Capture template commit for upgrade diffs
    template_commit = ""
    try:
        template_commit = run(["git", "rev-parse", "HEAD"], cwd=str(TEMPLATE_ROOT)).stdout.strip()
    except Exception:
        pass

    manifest["schema_version"] = 1
    manifest["integrated_at"] = dt.datetime.now().isoformat()
    manifest["template_commit"] = template_commit
    manifest["target"] = str(target)
    manifest["scan_summary"] = {
        "stacks": [{"stack": s["stack"], "root": s["root"], "framework": s["framework"], "app_name": s["app_name"]}
                   for s in plan["scan"]["scopes"]],
        "had_claude_md": plan["scan"]["existing_security"]["has_claude_md"],
        "had_pre_commit": plan["scan"]["existing_security"]["has_pre_commit"],
    }

    path.write_text(json.dumps(manifest, indent=2))
    info(f"Manifest: {plan['manifest_path']}")


# ───────────────────────── Verify ─────────────────────────

def verify(plan: dict) -> bool:
    target = Path(plan["target"])
    ok = True

    # Post-apply: run secure-mode.sh (same as adopt.sh does)
    secure_mode = target / ".cw-secure" / "secure-mode.sh"
    if secure_mode.exists():
        try:
            run(["bash", str(secure_mode)], cwd=str(target))
            info("secure-mode.sh ran cleanly")
        except subprocess.CalledProcessError as e:
            warn(f"secure-mode.sh exited non-zero: {e.stderr[:200]}")
            ok = False

    # Smoke: git status (sanity — confirm we're on the working branch with changes)
    if plan["scan"]["git"]["is_git_repo"]:
        status = run(["git", "status", "--short"], cwd=str(target), check=False)
        if status.stdout.strip():
            info(f"Changes staged for commit ({len(status.stdout.splitlines())} files)")

    return ok


# ───────────────────────── Main ─────────────────────────

def _load_portability_markers() -> dict:
    try:
        import yaml
        with open(HERE / "portability.yaml") as f:
            cfg = yaml.safe_load(f)
        return cfg.get("markers") or {}
    except ImportError:
        return {}


def _inject_markers(plan: dict) -> None:
    """Plan has marker keys (claude_md_start); apply needs real tokens."""
    tokens = _load_portability_markers()
    for act in plan["actions"]:
        if act.get("markers"):
            act["marker_tokens"] = tokens


def execute_plan(plan: dict, dry_run: bool) -> int:
    if dry_run:
        sys.path.insert(0, str(HERE))
        from plan import _print_plan
        _print_plan(plan)
        return 0

    target = Path(plan["target"])
    _inject_markers(plan)

    print(f"\n{BOLD}CW Secure — Apply{NC}")
    print("=" * 72)
    print(f"  Target:   {target}")
    stacks = ", ".join(f"{s['stack']}({s['app_name']})" for s in plan["scan"]["scopes"])
    print(f"  Stacks:   {stacks or '(none)'}")
    print()

    state = create_backup(plan)
    manifest = {"actions": []}

    try:
        for action in plan["actions"]:
            entry = {"action": action["action"], "dest": action["dest"]}
            executor = EXECUTORS.get(action["action"])
            if not executor:
                warn(f"Unknown action '{action['action']}' for {action['dest']}")
                entry["status"] = "skipped"
                manifest["actions"].append(entry)
                continue
            executor(action, target, entry)
            entry["status"] = "ok"
            manifest["actions"].append(entry)
    except Exception as e:
        error(f"Apply failed: {e}")
        rollback(str(target), state)
        raise

    write_manifest(plan, manifest)
    verify(plan)

    # Wiring snippets — the whole point of the generate action
    wires = [a for a in plan["actions"] if a.get("wiring_snippet")]
    if wires:
        print()
        print(f"  {BOLD}Wire up middleware — paste these snippets:{NC}")
        for w in wires:
            print(f"\n    {DIM}— {w['dest']}  ({w['scope']['stack']}):{NC}")
            for line in w["wiring_snippet"].splitlines():
                print(f"      {line}")

    print()
    info(f"{BOLD}Integration complete.{NC}")
    if state.get("branch"):
        print(f"    Review changes: cd {target} && git diff {state['tag']}")
        print(f"    Commit:         git add -A && git commit -m 'Add CW Secure integration'")
    return 0


def main():
    p = argparse.ArgumentParser(description="CW Secure Template — apply integration plan")
    p.add_argument("target", help="Path to target app directory")
    p.add_argument("--scope", default=None, help="Subpath to narrow scan")
    p.add_argument("--include-node", action="store_true", help="Include Node/Next integration")
    p.add_argument("--force", action="store_true", help="Skip safety gates (dirty tree, no-git)")
    p.add_argument("--dry-run", action="store_true", help="Print plan only, same as plan.py")
    args = p.parse_args()

    sys.path.insert(0, str(HERE))
    from plan import build_plan
    plan = build_plan(args.target, scope_filter=args.scope, include_node=args.include_node)

    if not args.dry_run:
        preflight(plan, force=args.force)

    sys.exit(execute_plan(plan, dry_run=args.dry_run))


if __name__ == "__main__":
    main()
