#!/usr/bin/env python3
"""
Merge CW Secure deny list and hooks into an existing .claude/settings.json.
Purely additive — never removes existing entries.

Usage: python3 adopt-merge-settings.py <target-settings.json> <cw-secure-dir>
"""

import json
import sys
import os


def main():
    if len(sys.argv) < 3:
        print("Usage: adopt-merge-settings.py <settings.json path> <cw-secure-dir>", file=sys.stderr)
        sys.exit(1)

    target_path = sys.argv[1]
    cw_dir = sys.argv[2]  # e.g. ".cw-secure"

    # Load existing or start empty
    settings = {}
    if os.path.exists(target_path):
        with open(target_path) as f:
            settings = json.load(f)

    # --- Merge deny list ---
    REQUIRED_DENY = [
        # Destructive git
        "Bash(git push --force *)",
        "Bash(git push -f *)",
        "Bash(git reset --hard *)",
        "Bash(git commit --no-verify *)",
        "Bash(git commit -n *)",
        "Bash(git stash drop *)",
        # Destructive shell
        "Bash(rm -rf *)",
        "Bash(chmod 777 *)",
        "Bash(chmod 666 *)",
        "Bash(curl * | bash)",
        "Bash(curl * | sh)",
        "Bash(wget * | bash)",
        "Bash(wget * | sh)",
        "Bash(eval *)",
        "Bash(dd *)",
        # CLAUDE.md protection
        "Bash(sed -i * CLAUDE.md)",
        "Bash(sed -i * .claude/*)",
        "Bash(> CLAUDE.md)",
        "Bash(> .claude/*)",
        "Bash(* > CLAUDE.md)",
        "Bash(* > .claude/*)",
        "Bash(* > .claude/settings.local.json)",
        "Bash(* >> CLAUDE.md)",
        "Bash(* >> .claude/*)",
        "Bash(truncate * CLAUDE.md)",
        "Bash(mv CLAUDE.md *)",
        "Bash(mv .claude *)",
        "Bash(pre-commit uninstall *)",
        "Bash(tee *)",
        "Bash(git config *)",
        # Guard introspection blocks
        f"Read({cw_dir}/guard.sh)",
        f"Read({cw_dir}/guards/*)",
        f"Read({cw_dir}/guard-bash.sh)",
        f"Grep({cw_dir}/guard*)",
        f"Glob({cw_dir}/guard*)",
    ]

    perms = settings.setdefault("permissions", {})
    existing_deny = perms.get("deny", [])
    existing_set = set(existing_deny)

    for item in REQUIRED_DENY:
        if item not in existing_set:
            existing_deny.append(item)
            existing_set.add(item)

    perms["deny"] = existing_deny

    # --- Merge hooks ---
    REQUIRED_HOOKS = {
        "PreToolUse": [
            {
                "matcher": "Edit|Write",
                "hooks": [{
                    "type": "command",
                    "command": f"bash {cw_dir}/guard.sh",
                    "timeout": 5000,
                    "statusMessage": "Checking security guardrails..."
                }]
            },
            {
                "matcher": "Bash",
                "hooks": [{
                    "type": "command",
                    "command": f"bash {cw_dir}/guard-bash.sh",
                    "timeout": 3000,
                    "statusMessage": "Checking command..."
                }]
            }
        ]
    }

    hooks = settings.setdefault("hooks", {})
    for event_name, event_hooks in REQUIRED_HOOKS.items():
        existing_event = hooks.get(event_name, [])
        # Collect existing command strings to avoid duplicates
        existing_cmds = set()
        for group in existing_event:
            for h in group.get("hooks", []):
                existing_cmds.add(h.get("command", ""))

        for hook_group in event_hooks:
            new_cmds = [h["command"] for h in hook_group["hooks"]]
            if not any(c in existing_cmds for c in new_cmds):
                existing_event.append(hook_group)

        hooks[event_name] = existing_event

    # Write back
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    with open(target_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")


if __name__ == "__main__":
    main()
