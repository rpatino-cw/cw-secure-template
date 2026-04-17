#!/usr/bin/env python3
"""
CW Secure Template — Plan Phase

Reads the portability map + scan results and produces a deterministic
integration plan. Writes nothing. Prints a human diff and optionally
emits plan.json for apply.py (not yet implemented — existing adopt.sh
still owns write execution).

Usage:
    python3 plan.py /path/to/target
    python3 plan.py /path/to/target --json
    python3 plan.py /path/to/target --scope=backend/ --include-node
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
TEMPLATE_ROOT = HERE.parent.parent


def _load_yaml(path: Path) -> dict:
    """Tiny YAML loader. Uses PyYAML if available, else a narrow fallback."""
    try:
        import yaml
        with open(path) as f:
            return yaml.safe_load(f)
    except ImportError:
        pass
    raise SystemExit(
        "PyYAML not installed. Run: pip install pyyaml\n"
        "(portability.yaml is structured YAML; a full parser is required.)"
    )


def _load_scan(target: str, scope: str | None, include_node: bool) -> dict:
    """Import and call scan.py in-process — avoids a subprocess dance."""
    sys.path.insert(0, str(HERE))
    import scan as scan_mod  # noqa: E402
    result = scan_mod.scan(target, scope_filter=scope, include_node=include_node)
    return scan_mod._to_dict(result)


def _populate(value: str, placeholders: dict[str, str]) -> str:
    if not isinstance(value, str):
        return value
    for key, val in placeholders.items():
        value = value.replace(f"{{{{{key}}}}}", str(val) if val is not None else "")
    return value


def _build_placeholders(scope: dict, scan_result: dict) -> dict[str, str]:
    mw_path = scope.get("middleware_path", "")
    return {
        "APP_NAME":         scope.get("app_name", ""),
        "STACK":            scope.get("stack", ""),
        "FRAMEWORK":        scope.get("framework", ""),
        "GO_MODULE":        scope.get("module", "") if scope.get("stack") == "go" else "",
        "PY_PACKAGE":       scope.get("module", "") if scope.get("stack") == "python" else "",
        "ENTRY_POINT":      scope.get("entry_point", ""),
        "MIDDLEWARE_PATH":  mw_path,
        "PY_IMPORT_PATH":   mw_path.replace("/", "."),   # for Python `from x.y.z import`
        "TEST_CMD":         scope.get("test_cmd", ""),
        "LINT_CMD":         scope.get("lint_cmd", ""),
        "AUTHOR":           scan_result.get("git", {}).get("author", ""),
    }


def _file_applies(entry: dict, scope: dict, include_node: bool) -> tuple[bool, str]:
    """Return (applies, skip_reason_if_not)."""
    if entry.get("always"):
        return True, ""
    stacks = entry.get("stacks") or []
    if scope["stack"] not in stacks:
        return False, f"file is for {stacks}, current scope is {scope['stack']}"
    if entry.get("opt_in") and scope["stack"] == "node" and not include_node:
        return False, "Node integration is opt-in; pass --include-node to include it"
    return True, ""


def _skip_if_detected(entry: dict, scan_result: dict) -> str:
    """Return a skip reason string if a 'skip_if_detected' rule matches, else ''."""
    rules = entry.get("skip_if_detected") or []
    es = scan_result["existing_security"]
    for rule in rules:
        checks = rule.get("existing_workflow_has") or []
        for check in checks:
            flag = f"ci_has_{check}"
            if es.get(flag):
                return rule.get("reason", f"detected existing {check} in CI")
    return ""


def build_plan(target: str, scope_filter: str | None, include_node: bool) -> dict:
    portability = _load_yaml(HERE / "portability.yaml")
    scan_result = _load_scan(target, scope_filter, include_node)

    actions: list = []
    skipped: list = []

    # Default placeholders for always-applies actions (uses first scope or safe fallback)
    default_placeholders = {}
    if scan_result["scopes"]:
        default_placeholders = _build_placeholders(scan_result["scopes"][0], scan_result)
    else:
        default_placeholders = {
            "APP_NAME": Path(scan_result["target"]).name,
            "AUTHOR":   scan_result.get("git", {}).get("author", ""),
        }

    for entry in portability["files"]:
        src = entry.get("source")
        dest = entry["dest"]
        action = entry["action"]

        # Always-applies files: emit one action (substitute with default placeholders)
        if entry.get("always") and not any(k in entry for k in ("stacks", "opt_in")):
            actions.append({
                "action": action,
                "source": src,
                "dest": _populate(dest, default_placeholders),
                "scope": None,
                "placeholders": default_placeholders,
                "rewrites": entry.get("rewrite", []),
                "strip_lines": entry.get("strip_lines", []),
                "markers": entry.get("markers", []),
                "patterns": entry.get("patterns", []),
                "merge_helper": entry.get("merge_helper"),
                "merge_strategy": entry.get("merge_strategy"),
                "if_missing": entry.get("if_missing"),
                "header": entry.get("header"),
                "skip_if_detected": _skip_if_detected(entry, scan_result),
            })
            continue

        # Stack-specific files: emit one action per matching scope
        # Track which stacks this entry targets so we can suppress N×M "wrong stack" noise
        entry_stacks = entry.get("stacks") or []
        emitted_for_stack = False
        for scope in scan_result["scopes"]:
            applies, why_not = _file_applies(entry, scope, include_node)
            if not applies:
                # Only report skip once per entry for wrong-stack (not per-scope)
                if scope["stack"] in entry_stacks or entry.get("opt_in"):
                    skipped.append({
                        "source": src,
                        "dest": dest,
                        "reason": why_not,
                        "scope_root": scope["root"],
                        "scope_stack": scope["stack"],
                    })
                continue
            emitted_for_stack = True

            placeholders = _build_placeholders(scope, scan_result)
            resolved_dest = _populate(dest, placeholders)
            resolved_snippet = _populate(entry.get("wiring_snippet", ""), placeholders)

            actions.append({
                "action": action,
                "source": src,
                "dest": resolved_dest,
                "scope": {"stack": scope["stack"], "root": scope["root"], "app_name": scope["app_name"]},
                "placeholders": placeholders,
                "wiring_snippet": resolved_snippet,
                "skip_if_detected": _skip_if_detected(entry, scan_result),
            })

    # Filter skip-if-detected into the skipped list
    final_actions = []
    for act in actions:
        if act.get("skip_if_detected"):
            skipped.append({
                "source": act["source"],
                "dest": act["dest"],
                "reason": act["skip_if_detected"],
                "scope_stack": (act.get("scope") or {}).get("stack"),
            })
        else:
            final_actions.append(act)

    return {
        "target": scan_result["target"],
        "scan": scan_result,
        "actions": final_actions,
        "skipped_items": skipped,
        "safety": portability.get("safety", {}),
        "manifest_path": portability.get("manifest", {}).get("path", ".cw-integrate-manifest.json"),
    }


# ───────────────────────── Human output ─────────────────────────

ACTION_STYLE = {
    "copy":     "+ COPY    ",
    "merge":    "~ MERGE   ",
    "append":   "> APPEND  ",
    "generate": "✱ GENERATE",
}


def _print_plan(plan: dict) -> None:
    target = plan["target"]
    scan = plan["scan"]
    print(f"\nIntegration plan for: {target}")
    print("=" * min(len(target) + 22, 72))

    # Header: stacks
    if scan["scopes"]:
        stacks = ", ".join(f"{s['stack']}({s['app_name']})" for s in scan["scopes"])
        print(f"  Stacks: {stacks}")
    else:
        print("  Stacks: (none detected — plan will be empty)")

    # Warnings from scan
    for w in scan.get("warnings", []):
        print(f"  ! {w}")
    for a in scan.get("ambiguities", []):
        print(f"  ? {a}")

    print()
    print(f"  Actions ({len(plan['actions'])}):")
    for act in plan["actions"]:
        style = ACTION_STYLE.get(act["action"], act["action"])
        scope = act.get("scope")
        suffix = f"  [{scope['stack']}@{scope['root'] or '.'}]" if scope else ""
        src = act.get("source") or "(inline)"
        print(f"    {style} {act['dest']:<50}  ← {src}{suffix}")

    if plan["skipped_items"]:
        print()
        print(f"  Skipped ({len(plan['skipped_items'])}):")
        for s in plan["skipped_items"]:
            print(f"    ✗ {s['dest']:<50}  ({s['reason']})")

    # Wiring snippets are the part the user has to paste
    wires = [a for a in plan["actions"] if a.get("wiring_snippet")]
    if wires:
        print()
        print("  Wiring snippets you'll need to paste after apply:")
        for w in wires:
            print(f"\n    — for {w['dest']}  ({w['scope']['stack']}):")
            for line in w["wiring_snippet"].splitlines():
                print(f"      {line}")

    print()
    print(f"  Safety rails: {plan['safety']}")
    print(f"  Manifest will be written to: {plan['manifest_path']}")
    print()
    print("  Next: review this plan. When ready:")
    print("    make adopt TARGET=" + target)
    print("  (Note: apply.py not yet wired — adopt.sh handles writes for now.)")
    print()


def main():
    p = argparse.ArgumentParser(description="CW Secure Template — build an integration plan")
    p.add_argument("target", help="Path to the target app directory")
    p.add_argument("--scope", default=None, help="Subpath to narrow scan")
    p.add_argument("--include-node", action="store_true", help="Also plan Node/Next integrations")
    p.add_argument("--json", action="store_true", help="Emit plan.json to stdout")
    args = p.parse_args()

    plan = build_plan(args.target, scope_filter=args.scope, include_node=args.include_node)

    if args.json:
        # strip the full scan.scopes objects for brevity if JSON
        print(json.dumps(plan, indent=2, default=str))
    else:
        _print_plan(plan)


if __name__ == "__main__":
    main()
