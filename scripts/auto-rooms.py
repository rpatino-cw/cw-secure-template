#!/usr/bin/env python3
"""Auto-detect project structure and generate rooms.json.

Scans the codebase, identifies logical modules by directory structure
and file patterns, and outputs a rooms.json config. No AI needed —
pure heuristics.

Usage:
    python3 scripts/auto-rooms.py           # prints rooms.json to stdout
    python3 scripts/auto-rooms.py --write   # writes rooms.json to disk
"""

import json
import os
import sys
from collections import defaultdict
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# Directories to always skip
SKIP_DIRS = {
    ".git", "node_modules", "__pycache__", ".venv", "venv",
    ".claude", "rooms", ".devcontainer", "vendor", "dist", "build",
}

# ── Language / framework detection ─────────────────────────

LANG_SIGNALS = {
    "go": {
        "extensions": {".go"},
        "markers": {"go.mod", "go.sum"},
        "label": "Go application",
    },
    "python": {
        "extensions": {".py"},
        "markers": {"pyproject.toml", "setup.py", "requirements.txt", "Pipfile"},
        "label": "Python application",
    },
    "node": {
        "extensions": {".js", ".ts", ".mjs", ".cjs"},
        "markers": {"package.json", "tsconfig.json"},
        "label": "Node.js application",
    },
    "rust": {
        "extensions": {".rs"},
        "markers": {"Cargo.toml"},
        "label": "Rust application",
    },
    "java": {
        "extensions": {".java", ".kt"},
        "markers": {"pom.xml", "build.gradle", "build.gradle.kts"},
        "label": "Java/Kotlin application",
    },
}

# Purpose-based directory patterns
PURPOSE_PATTERNS = {
    "ci": {
        "dirs": {".github", ".gitlab", ".circleci"},
        "files": {".github/workflows", ".gitlab-ci.yml", "Jenkinsfile", ".travis.yml"},
        "label": "CI/CD pipelines, branch protection, PR templates",
        "color": "purple",
    },
    "docs": {
        "dirs": {"docs", "documentation", "wiki"},
        "files": set(),
        "label": "Documentation, guides, handbooks",
        "color": "cyan",
    },
    "deploy": {
        "dirs": {"deploy", "helm", "k8s", "kubernetes", "terraform", "infra", "infrastructure"},
        "files": {"docker-compose.yml", "docker-compose.yaml", "Dockerfile"},
        "label": "Infrastructure, deployment, containers",
        "color": "orange",
    },
    "frontend": {
        "dirs": {"frontend", "web", "client", "ui", "app", "public", "static"},
        "files": set(),
        "label": "Frontend — UI, components, styles",
        "color": "blue",
    },
}

# Files that are always "shared" — no single owner
SHARED_PATTERNS = [
    "CLAUDE.md", ".claude/rules/", ".claude/settings.json",
    ".env.example", ".gitignore", "README.md", "LICENSE",
    "docker-compose.yml", "Makefile", "rooms.json",
]


def scan_project() -> dict:
    """Walk the project tree and collect intelligence."""
    info = {
        "top_dirs": [],           # first-level directories
        "lang_dirs": {},          # dir → detected language
        "purpose_dirs": {},       # dir → detected purpose
        "file_counts": defaultdict(int),  # dir → file count
        "extensions": defaultdict(set),   # dir → set of extensions
        "script_dirs": set(),     # dirs containing shell scripts
        "test_dirs": set(),       # dirs that are test-only
    }

    # Scan top-level directories
    for entry in sorted(REPO_ROOT.iterdir()):
        if entry.is_dir() and entry.name not in SKIP_DIRS and not entry.name.startswith("."):
            info["top_dirs"].append(entry.name)

    # Analyze each top-level directory
    for dirname in info["top_dirs"]:
        dirpath = REPO_ROOT / dirname
        exts = set()
        count = 0
        has_tests_only = True

        for root, dirs, files in os.walk(dirpath):
            # Skip ignored dirs
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            for f in files:
                count += 1
                ext = Path(f).suffix
                if ext:
                    exts.add(ext)
                # Check if ALL files are tests
                if not any(t in f.lower() for t in ("test", "spec", "_test.", ".test.")):
                    has_tests_only = False

        info["file_counts"][dirname] = count
        info["extensions"][dirname] = exts

        if count > 0 and has_tests_only:
            info["test_dirs"].add(dirname)

        # Detect language by markers and extensions
        for lang, signals in LANG_SIGNALS.items():
            # Check for marker files
            for marker in signals["markers"]:
                if (dirpath / marker).exists():
                    info["lang_dirs"][dirname] = lang
                    break
            # Check dominant extension
            if dirname not in info["lang_dirs"]:
                lang_exts = signals["extensions"]
                if lang_exts & exts:
                    # Count how many files match
                    lang_count = sum(
                        1 for root, _, files in os.walk(dirpath)
                        for f in files if Path(f).suffix in lang_exts
                    )
                    if lang_count >= count * 0.4:  # 40%+ of files
                        info["lang_dirs"][dirname] = lang

        # Detect purpose (only match if the directory itself matches the pattern)
        for purpose, patterns in PURPOSE_PATTERNS.items():
            if dirname in patterns["dirs"]:
                info["purpose_dirs"][dirname] = purpose
            for pfile in patterns["files"]:
                # Only check within this directory, not at repo root
                if (dirpath / pfile).exists():
                    if dirname not in info["purpose_dirs"]:
                        info["purpose_dirs"][dirname] = purpose

        # Check for shell scripts
        if any(f.endswith(".sh") for _, _, files in os.walk(dirpath) for f in files):
            info["script_dirs"].add(dirname)

    # Also check for .github at root level
    for purpose, patterns in PURPOSE_PATTERNS.items():
        for pdir in patterns["dirs"]:
            if (REPO_ROOT / pdir).is_dir():
                info["purpose_dirs"][pdir] = purpose

    return info


def generate_rooms(info: dict) -> dict:
    """Turn scan results into a rooms.json config."""
    rooms = {}
    assigned_dirs = set()

    # Color palette for auto-assignment
    colors = ["blue", "green", "red", "yellow", "purple", "cyan", "orange", "pink"]
    color_idx = 0

    def next_color():
        nonlocal color_idx
        c = colors[color_idx % len(colors)]
        color_idx += 1
        return c

    # 1. Create rooms for language-specific directories
    for dirname, lang in sorted(info["lang_dirs"].items()):
        if dirname in assigned_dirs:
            continue
        signals = LANG_SIGNALS[lang]
        room_name = f"{dirname}"
        rooms[room_name] = {
            "description": f"{signals['label']} — endpoints, models, tests",
            "owns": [f"{dirname}/"],
            "color": next_color(),
        }
        assigned_dirs.add(dirname)

    # 2. Create rooms for purpose-specific directories
    for dirname, purpose in sorted(info["purpose_dirs"].items()):
        if dirname in assigned_dirs:
            continue
        patterns = PURPOSE_PATTERNS[purpose]
        room_name = purpose
        # Merge if room already exists (e.g., multiple CI dirs)
        if room_name in rooms:
            rooms[room_name]["owns"].append(f"{dirname}/")
        else:
            rooms[room_name] = {
                "description": patterns["label"],
                "owns": [f"{dirname}/"],
                "color": patterns.get("color", next_color()),
            }
        assigned_dirs.add(dirname)

    # 3. Scripts directory → split into security + devex if both exist
    if "scripts" in info["top_dirs"] and "scripts" not in assigned_dirs:
        scripts_path = REPO_ROOT / "scripts"
        security_files = []
        devex_files = []

        for f in scripts_path.iterdir():
            if not f.is_file():
                continue
            name = f.name.lower()
            if any(w in name for w in ("guard", "security", "scan", "audit", "hook")):
                security_files.append(f"scripts/{f.name}")
            else:
                devex_files.append(f"scripts/{f.name}")

        # Also check for git-hooks subdir
        git_hooks_dir = scripts_path / "git-hooks"
        if git_hooks_dir.is_dir():
            security_files.append("scripts/git-hooks/")

        if security_files:
            rooms["security"] = {
                "description": "Guard hooks, security scanning, git hooks",
                "owns": security_files,
                "color": "red",
            }
        if devex_files:
            rooms["devex"] = {
                "description": "Developer scripts, setup, tooling, onboarding",
                "owns": devex_files + (["Makefile"] if (REPO_ROOT / "Makefile").exists() else [])
                    + (["setup.sh"] if (REPO_ROOT / "setup.sh").exists() else []),
                "color": "yellow",
            }
        if not security_files and not devex_files:
            rooms["scripts"] = {
                "description": "Project scripts and tooling",
                "owns": ["scripts/"],
                "color": next_color(),
            }
        assigned_dirs.add("scripts")

    # 4. Remaining unassigned top-level dirs — only if substantial (5+ files)
    for dirname in info["top_dirs"]:
        if dirname in assigned_dirs:
            continue
        if info["file_counts"].get(dirname, 0) < 5:
            continue  # skip small dirs — not worth a dedicated room
        if dirname in info["test_dirs"]:
            continue  # tests merge with their parent room

        rooms[dirname] = {
            "description": f"{dirname.replace('-', ' ').replace('_', ' ').title()} module",
            "owns": [f"{dirname}/"],
            "color": next_color(),
        }
        assigned_dirs.add(dirname)

    # 5. Consolidate — merge small rooms into related ones, cap at 5
    MAX_ROOMS = 5
    if len(rooms) > MAX_ROOMS:
        # Merge non-language rooms with fewest owned paths into nearest neighbor
        # Priority to keep: language rooms > security > ci > everything else
        keep_priority = []
        merge_candidates = []
        for name, room in rooms.items():
            if name in info.get("lang_dirs", {}).values() or name in [d for d in info.get("lang_dirs", {})]:
                keep_priority.append(name)
            elif name == "security":
                keep_priority.append(name)
            elif name == "ci":
                keep_priority.append(name)
            else:
                merge_candidates.append(name)

        # Sort merge candidates by owned file count (smallest first)
        merge_candidates.sort(key=lambda n: sum(
            info["file_counts"].get(p.rstrip("/"), 0) for p in rooms[n]["owns"]
        ))

        # Merge smallest rooms into devex (or create it as the catch-all)
        while len(rooms) > MAX_ROOMS and merge_candidates:
            victim = merge_candidates.pop(0)
            target = "devex" if "devex" in rooms else (keep_priority[-1] if keep_priority else list(rooms.keys())[0])
            if target in rooms and victim in rooms:
                rooms[target]["owns"].extend(rooms[victim]["owns"])
                del rooms[victim]

    # 6. Determine shared files — exclude any that are already owned by a room
    all_owned = set()
    for room in rooms.values():
        for p in room["owns"]:
            all_owned.add(p.rstrip("/"))
    shared_paths = [
        p for p in SHARED_PATTERNS
        if (REPO_ROOT / p).exists() or (REPO_ROOT / p.rstrip("/")).exists()
        if p.rstrip("/") not in all_owned
    ]

    # Pick an approver — prefer security room, else first room
    approver = "security" if "security" in rooms else (list(rooms.keys())[0] if rooms else "none")

    # 7. If no rooms were detected, create a single "dev" room that owns everything
    if not rooms:
        rooms["dev"] = {
            "description": "All project source code",
            "owns": ["./"],
            "color": "blue",
        }

    config = {
        "version": 1,
        "description": "Auto-generated room config. Edit to customize ownership.",
        "auto_generated": True,
        "rooms": rooms,
        "shared": {
            "description": "Files that require a request to edit — no single owner",
            "paths": shared_paths,
            "approver": approver,
        },
    }

    return config


def print_summary(config: dict):
    """Print a human-readable summary."""
    rooms = config["rooms"]
    print(f"\n  Auto-detected {len(rooms)} room(s):\n")
    for name, room in rooms.items():
        owns = ", ".join(room["owns"])
        print(f"    {name:<20} → {owns}")
        print(f"    {'':20}   {room['description']}")
    shared = config["shared"]["paths"]
    if shared:
        print(f"\n  Shared files ({len(shared)}): {', '.join(shared[:5])}")
        if len(shared) > 5:
            print(f"    ... and {len(shared) - 5} more")
    print(f"  Approver: {config['shared']['approver']}")
    print()


def main():
    write_mode = "--write" in sys.argv

    info = scan_project()
    config = generate_rooms(info)

    if write_mode:
        out_path = REPO_ROOT / "rooms.json"
        if out_path.exists():
            print("  rooms.json already exists. Delete it first to regenerate.")
            print("  Or edit it manually — auto-generation only runs on first setup.")
            sys.exit(1)
        with open(out_path, "w") as f:
            json.dump(config, f, indent=2)
            f.write("\n")
        print(f"  Wrote rooms.json")
        print_summary(config)
    else:
        print(json.dumps(config, indent=2))
        print_summary(config)


if __name__ == "__main__":
    main()
