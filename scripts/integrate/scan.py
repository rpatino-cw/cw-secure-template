#!/usr/bin/env python3
"""
CW Secure Template — Scan Phase

Read-only inspection of a target app directory. Detects:
  - Stack(s): go, python, node (multi-scope for monorepos)
  - Framework per stack: fastapi/flask/django, gin/chi/echo, next/express/fastify
  - Existing security posture: pre-commit, CI workflows, CLAUDE.md, .claude/
  - Git state: repo root, dirty tree, current branch
  - Populate values: app_name, entry_point, module paths, test/lint commands

Outputs scan.json to stdout. Writes nothing.

Usage:
    python3 scan.py /path/to/target/app
    python3 scan.py /path/to/target/app --scope=backend/
    python3 scan.py /path/to/target/app --json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path


SCAN_MAX_DEPTH = 3
EXT_SAMPLE_LIMIT = 2000

GO_FRAMEWORKS = {
    "gin-gonic/gin": "gin",
    "gorilla/mux": "gorilla",
    "go-chi/chi": "chi",
    "labstack/echo": "echo",
    "gofiber/fiber": "fiber",
}

PY_FRAMEWORKS = {
    "fastapi": "fastapi",
    "flask": "flask",
    "django": "django",
    "starlette": "starlette",
    "aiohttp": "aiohttp",
}

NODE_FRAMEWORKS = {
    "next": "next",
    "express": "express",
    "fastify": "fastify",
    "koa": "koa",
    "@nestjs/core": "nestjs",
    "hapi": "hapi",
}


@dataclass
class Scope:
    stack: str                  # go | python | node
    root: str                   # relative to target root, e.g. "" or "backend"
    framework: str = "unknown"
    app_name: str = ""
    entry_point: str = ""
    module: str = ""            # go module path | pypackage name | npm package name
    middleware_path: str = ""
    test_cmd: str = ""
    lint_cmd: str = ""
    deps: list = field(default_factory=list)


@dataclass
class ExistingSecurity:
    has_pre_commit: bool = False
    pre_commit_has_gitleaks: bool = False
    ci_workflows: list = field(default_factory=list)
    ci_has_gosec: bool = False
    ci_has_bandit: bool = False
    ci_has_codeql: bool = False
    ci_has_gitleaks: bool = False
    has_claude_md: bool = False
    has_claude_settings: bool = False
    has_claude_rules: bool = False
    has_cw_secure_adopted: bool = False


@dataclass
class GitState:
    is_git_repo: bool = False
    dirty: bool = False
    branch: str = ""
    remote: str = ""
    author: str = ""


@dataclass
class ScanResult:
    target: str
    scopes: list
    existing_security: ExistingSecurity
    git: GitState
    warnings: list = field(default_factory=list)
    ambiguities: list = field(default_factory=list)


# ───────────────────────── Helpers ─────────────────────────

def _run(cmd: list, cwd: str) -> str:
    try:
        out = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, timeout=5, check=False
        )
        return out.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return ""


def _iter_dirs(root: Path, max_depth: int):
    root = root.resolve()
    yield root
    for path in root.rglob("*"):
        if not path.is_dir():
            continue
        depth = len(path.relative_to(root).parts)
        if depth > max_depth:
            continue
        # Prune noise
        if any(part.startswith(".") for part in path.relative_to(root).parts):
            continue
        if any(p in path.parts for p in ("node_modules", "vendor", "__pycache__", "dist", "build", ".venv", "venv", "target")):
            continue
        yield path


# ───────────────────────── Stack detection ─────────────────────────

def detect_go_scope(dir_path: Path, target_root: Path) -> Scope | None:
    go_mod = dir_path / "go.mod"
    if not go_mod.exists():
        return None

    rel = str(dir_path.relative_to(target_root)) if dir_path != target_root else ""
    text = go_mod.read_text(errors="ignore")

    module_match = re.search(r"^module\s+(\S+)", text, re.MULTILINE)
    module = module_match.group(1) if module_match else ""

    framework = "unknown"
    deps: list = []
    for dep_key, fw in GO_FRAMEWORKS.items():
        if dep_key in text:
            framework = fw
            deps.append(dep_key)

    # Entry point: prefer cmd/*/main.go, then main.go at stack root
    entry = ""
    cmd_dir = dir_path / "cmd"
    if cmd_dir.is_dir():
        mains = list(cmd_dir.glob("*/main.go"))
        if mains:
            entry = str(mains[0].relative_to(target_root))
    if not entry:
        main_go = dir_path / "main.go"
        if main_go.exists():
            entry = str(main_go.relative_to(target_root))

    # Middleware path: existing internal/middleware or middleware; fallback to internal/middleware
    mw = ""
    for candidate in ("internal/middleware", "middleware", "pkg/middleware"):
        if (dir_path / candidate).is_dir():
            mw = str((dir_path / candidate).relative_to(target_root))
            break
    if not mw:
        mw = str((dir_path / "internal/middleware").relative_to(target_root))

    return Scope(
        stack="go",
        root=rel,
        framework=framework,
        app_name=module.rsplit("/", 1)[-1] if module else dir_path.name,
        entry_point=entry,
        module=module,
        middleware_path=mw,
        test_cmd="go test ./...",
        lint_cmd="golangci-lint run",
        deps=deps,
    )


def detect_python_scope(dir_path: Path, target_root: Path) -> Scope | None:
    pyproject = dir_path / "pyproject.toml"
    setup_py = dir_path / "setup.py"
    reqs = dir_path / "requirements.txt"

    if not any(p.exists() for p in (pyproject, setup_py, reqs)):
        return None

    rel = str(dir_path.relative_to(target_root)) if dir_path != target_root else ""

    name = dir_path.name
    deps_text = ""
    framework = "unknown"
    deps: list = []

    if pyproject.exists():
        deps_text = pyproject.read_text(errors="ignore")
        m = re.search(r'^name\s*=\s*"([^"]+)"', deps_text, re.MULTILINE)
        if m:
            name = m.group(1)

    if reqs.exists():
        deps_text += "\n" + reqs.read_text(errors="ignore")
    if setup_py.exists():
        deps_text += "\n" + setup_py.read_text(errors="ignore")

    low = deps_text.lower()
    for dep_key, fw in PY_FRAMEWORKS.items():
        if re.search(rf"\b{re.escape(dep_key)}\b", low):
            framework = fw
            deps.append(dep_key)

    # Entry point: src/main.py > app/main.py > main.py > app.py
    entry = ""
    for candidate in ("src/main.py", "app/main.py", "main.py", "app.py", "src/app.py"):
        cand = dir_path / candidate
        if cand.exists():
            entry = str(cand.relative_to(target_root))
            break

    # Middleware path
    mw = ""
    for candidate in ("src/middleware", "app/middleware", "middleware"):
        if (dir_path / candidate).is_dir():
            mw = str((dir_path / candidate).relative_to(target_root))
            break
    if not mw:
        base = "src" if (dir_path / "src").is_dir() else "."
        mw = str((dir_path / base / "middleware").relative_to(target_root))

    return Scope(
        stack="python",
        root=rel,
        framework=framework,
        app_name=name,
        entry_point=entry,
        module=name,
        middleware_path=mw,
        test_cmd="pytest",
        lint_cmd="ruff check .",
        deps=deps,
    )


def detect_node_scope(dir_path: Path, target_root: Path) -> Scope | None:
    pkg = dir_path / "package.json"
    if not pkg.exists():
        return None

    try:
        data = json.loads(pkg.read_text(errors="ignore"))
    except json.JSONDecodeError:
        return None

    rel = str(dir_path.relative_to(target_root)) if dir_path != target_root else ""

    combined_deps = {}
    combined_deps.update(data.get("dependencies") or {})
    combined_deps.update(data.get("devDependencies") or {})

    framework = "unknown"
    deps: list = []
    for dep_key, fw in NODE_FRAMEWORKS.items():
        if dep_key in combined_deps:
            framework = fw
            deps.append(dep_key)

    # Skip if it's purely a tooling package (no real framework)
    if framework == "unknown" and not any(
        f in combined_deps for f in ("react", "vue", "svelte", "typescript")
    ):
        return None

    name = data.get("name", dir_path.name)

    # Entry point
    entry = ""
    for candidate in ("src/index.ts", "src/index.js", "app.ts", "app.js", "index.ts", "index.js", "server.ts", "server.js"):
        cand = dir_path / candidate
        if cand.exists():
            entry = str(cand.relative_to(target_root))
            break
    if not entry and data.get("main"):
        entry = str((dir_path / data["main"]).relative_to(target_root))

    mw = ""
    for candidate in ("src/middleware", "middleware"):
        if (dir_path / candidate).is_dir():
            mw = str((dir_path / candidate).relative_to(target_root))
            break
    if not mw:
        mw = str((dir_path / "src/middleware").relative_to(target_root))

    scripts = data.get("scripts", {})
    test_cmd = "npm test" if "test" in scripts else ""
    lint_cmd = "npm run lint" if "lint" in scripts else ""

    return Scope(
        stack="node",
        root=rel,
        framework=framework,
        app_name=name,
        entry_point=entry,
        module=name,
        middleware_path=mw,
        test_cmd=test_cmd,
        lint_cmd=lint_cmd,
        deps=deps,
    )


# ───────────────────────── Existing security detection ─────────────────────────

def detect_existing_security(target: Path) -> ExistingSecurity:
    es = ExistingSecurity()
    pre_commit = target / ".pre-commit-config.yaml"
    if pre_commit.exists():
        es.has_pre_commit = True
        es.pre_commit_has_gitleaks = "gitleaks" in pre_commit.read_text(errors="ignore").lower()

    workflows_dir = target / ".github" / "workflows"
    if workflows_dir.is_dir():
        for wf in workflows_dir.glob("*.y*ml"):
            es.ci_workflows.append(str(wf.relative_to(target)))
            body = wf.read_text(errors="ignore").lower()
            if "gosec" in body:   es.ci_has_gosec = True
            if "bandit" in body:  es.ci_has_bandit = True
            if "codeql" in body:  es.ci_has_codeql = True
            if "gitleaks" in body: es.ci_has_gitleaks = True

    es.has_claude_md       = (target / "CLAUDE.md").exists()
    es.has_claude_settings = (target / ".claude" / "settings.json").exists()
    es.has_claude_rules    = (target / ".claude" / "rules").is_dir()
    es.has_cw_secure_adopted = (target / ".cw-secure").is_dir()
    return es


# ───────────────────────── Git state ─────────────────────────

def detect_git_state(target: Path) -> GitState:
    gs = GitState()
    if not (target / ".git").exists():
        return gs
    toplevel = _run(["git", "rev-parse", "--show-toplevel"], str(target))
    if not toplevel:
        return gs
    gs.is_git_repo = True
    gs.branch = _run(["git", "rev-parse", "--abbrev-ref", "HEAD"], str(target))
    gs.remote = _run(["git", "config", "--get", "remote.origin.url"], str(target))
    gs.author = _run(["git", "config", "--get", "user.name"], str(target))
    status = _run(["git", "status", "--porcelain"], str(target))
    gs.dirty = bool(status)
    return gs


# ───────────────────────── Main ─────────────────────────

def scan(target_path: str, scope_filter: str | None = None, include_node: bool = False) -> ScanResult:
    target = Path(target_path).expanduser().resolve()
    if not target.is_dir():
        raise SystemExit(f"Target not found: {target}")

    scopes = []
    warnings: list = []
    ambiguities: list = []

    search_root = target / scope_filter if scope_filter else target
    if not search_root.is_dir():
        raise SystemExit(f"Scope filter path not found: {search_root}")

    seen_roots = set()
    for d in _iter_dirs(search_root, SCAN_MAX_DEPTH):
        if str(d) in seen_roots:
            continue

        for detector in (detect_go_scope, detect_python_scope, detect_node_scope):
            if detector is detect_node_scope and not include_node:
                continue
            scope = detector(d, target)
            if scope:
                scopes.append(scope)
                seen_roots.add(str(d))
                break

    if not scopes:
        warnings.append(
            "No Go/Python/Node stack detected. Run with --include-node if this is a Node-only app, "
            "or --scope=<subpath> to narrow the search."
        )

    if len(scopes) > 1:
        stacks = {s.stack for s in scopes}
        if len(stacks) > 1:
            ambiguities.append(
                f"Multiple stacks detected: {sorted(stacks)}. "
                "Re-run with --scope=<subpath> to target one, or the planner will integrate into each."
            )

    es = detect_existing_security(target)
    git = detect_git_state(target)

    if es.has_cw_secure_adopted:
        warnings.append(".cw-secure/ already present — this target was previously adopted. Run `make integrate` with FORCE=1 to refresh.")
    if git.is_git_repo and git.dirty:
        warnings.append(f"Working tree is dirty on branch '{git.branch}'. Commit or stash before applying.")
    if not git.is_git_repo:
        warnings.append("Target is not a git repository. Safety rails (backup tag, working branch) will be disabled.")

    return ScanResult(
        target=str(target),
        scopes=scopes,
        existing_security=es,
        git=git,
        warnings=warnings,
        ambiguities=ambiguities,
    )


def _to_dict(result: ScanResult) -> dict:
    d = asdict(result)
    d["scopes"] = [asdict(s) for s in result.scopes]
    d["existing_security"] = asdict(result.existing_security)
    d["git"] = asdict(result.git)
    return d


def _print_human(r: ScanResult) -> None:
    print(f"\nScan: {r.target}")
    print("=" * min(len(r.target) + 6, 72))

    if not r.scopes:
        print("  Stacks:   (none detected)")
    else:
        print(f"  Stacks:   {len(r.scopes)} scope(s)")
        for s in r.scopes:
            label = f"[{s.root or '.'}]"
            print(f"    {label:20} {s.stack:6} framework={s.framework:10} app={s.app_name}")
            if s.entry_point:
                print(f"    {'':20} entry={s.entry_point}")
            if s.middleware_path:
                print(f"    {'':20} middleware→{s.middleware_path}")

    es = r.existing_security
    print(f"\n  Existing security:")
    print(f"    pre-commit:      {'yes' if es.has_pre_commit else 'no':4} (gitleaks: {es.pre_commit_has_gitleaks})")
    print(f"    CI workflows:    {len(es.ci_workflows)} found "
          f"(gosec={es.ci_has_gosec}, bandit={es.ci_has_bandit}, codeql={es.ci_has_codeql}, gitleaks={es.ci_has_gitleaks})")
    print(f"    CLAUDE.md:       {'yes' if es.has_claude_md else 'no'}")
    print(f"    .claude/:        settings={es.has_claude_settings}, rules={es.has_claude_rules}")
    print(f"    .cw-secure/:     {'ALREADY ADOPTED' if es.has_cw_secure_adopted else 'not present'}")

    g = r.git
    print(f"\n  Git:")
    if not g.is_git_repo:
        print(f"    NOT A GIT REPO")
    else:
        print(f"    branch={g.branch} dirty={g.dirty}")
        if g.remote:
            print(f"    remote={g.remote}")

    if r.ambiguities:
        print(f"\n  Ambiguities:")
        for a in r.ambiguities:
            print(f"    ! {a}")
    if r.warnings:
        print(f"\n  Warnings:")
        for w in r.warnings:
            print(f"    - {w}")
    print()


def main():
    p = argparse.ArgumentParser(description="CW Secure Template — scan a target app")
    p.add_argument("target", help="Path to the target app directory")
    p.add_argument("--scope", default=None, help="Subpath to narrow scan (e.g. backend/)")
    p.add_argument("--json", action="store_true", help="Emit scan.json to stdout (for plan.py)")
    p.add_argument("--include-node", action="store_true", help="Also detect Node/Next stacks")
    args = p.parse_args()

    result = scan(args.target, scope_filter=args.scope, include_node=args.include_node)

    if args.json:
        print(json.dumps(_to_dict(result), indent=2))
    else:
        _print_human(result)


if __name__ == "__main__":
    main()
