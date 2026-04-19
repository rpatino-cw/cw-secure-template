"""
CWT import graph — Phase 3 MVP.

Walks the project tree for Python files, parses imports via ast, emits a
{nodes, edges} graph of internal dependencies (imports resolving to other
files in the project). Third-party and stdlib imports are dropped —
only edges between project files are kept.

Stdlib only. Used by /api/graph and `make cwt-graph`.
"""

import ast
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__", ".pytest_cache",
    "dist", "build", ".mypy_cache", ".ruff_cache", ".idea", ".vscode",
}

TOOLING_PREFIXES = (".cwt/", ".cwt-build/", "scripts/")


def _is_skipped(path):
    for part in path.parts:
        if part in SKIP_DIRS:
            return True
    return False


def _collect_py_files(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith(".py"):
                full = Path(dirpath) / fn
                rel = full.relative_to(root)
                if not _is_skipped(rel):
                    out.append(rel)
    return sorted(out)


def _module_name(relpath):
    """Convert rel/foo/bar.py -> foo.bar (drop __init__ suffix)."""
    parts = list(relpath.with_suffix("").parts)
    if parts and parts[-1] == "__init__":
        parts.pop()
    return ".".join(parts)


def _parse_imports(path):
    """Return list of imported module names from a Python file."""
    try:
        tree = ast.parse(path.read_text())
    except Exception:
        return []
    out = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for n in node.names:
                out.append(n.name)
        elif isinstance(node, ast.ImportFrom) and node.module:
            out.append(node.module)
    return out


def _resolve(module, modules_by_name):
    """Return the file path for `module` if it's an internal module, else None."""
    if module in modules_by_name:
        return modules_by_name[module]
    # Also try parent paths for `from foo.bar import baz`
    parts = module.split(".")
    while parts:
        parts.pop()
        parent = ".".join(parts)
        if parent and parent in modules_by_name:
            return modules_by_name[parent]
    return None


def _is_tooling(rel_path_str):
    return rel_path_str.startswith(TOOLING_PREFIXES)


def build_graph(root=None):
    """Return {nodes, edges, stats}."""
    root = Path(root) if root else ROOT
    files = _collect_py_files(root)
    modules_by_name = {_module_name(f): str(f) for f in files}

    nodes = []
    edges = []
    for f in files:
        rel = str(f)
        nodes.append({
            "id": rel,
            "module": _module_name(f),
            "tooling": _is_tooling(rel),
        })
    seen_edges = set()
    for f in files:
        src = str(f)
        for imp in _parse_imports(root / f):
            dst = _resolve(imp, modules_by_name)
            if dst and dst != src:
                key = (src, dst)
                if key in seen_edges:
                    continue
                seen_edges.add(key)
                edges.append({"from": src, "to": dst})

    return {
        "nodes": nodes,
        "edges": edges,
        "stats": {
            "files": len(nodes),
            "internal_edges": len(edges),
            "tooling_files": sum(1 for n in nodes if n["tooling"]),
        },
    }
