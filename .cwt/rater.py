"""
CWT rater — Phase 2 v1.

Rule-based conformance scorer for plan targets. Parses `# Glob:` headers
from .claude/rules/*.md, matches each plan target's path against applicable
rules, and scores based on which rules the justification text cites.

Stdlib only. Imported by server.py inside rebuild_manifest().
"""

import re
from pathlib import Path

RULES_DIR = Path(__file__).resolve().parent.parent / ".claude" / "rules"

CATCH_ALL = {"collaboration", "routing", "rooms", "branching"}
EXEMPT_PREFIXES = (".cwt/", ".cwt-build/")


def _expand_braces(s):
    m = re.search(r"\{([^{}]+)\}", s)
    if not m:
        return [s]
    options = m.group(1).split(",")
    prefix, suffix = s[: m.start()], s[m.end() :]
    out = []
    for opt in options:
        out.extend(_expand_braces(prefix + opt + suffix))
    return out


def _glob_to_regex(glob):
    patterns = []
    for expanded in _expand_braces(glob):
        pat = re.escape(expanded)
        # **/ matches zero or more path segments (so **/routes/** matches routes/x)
        pat = pat.replace(r"\*\*/", r"(?:.*/)?")
        # Standalone ** matches anything (including /)
        pat = pat.replace(r"\*\*", r".*")
        # Single * matches one path segment (no /)
        pat = pat.replace(r"\*", r"[^/]*")
        # ? matches one char
        pat = pat.replace(r"\?", r".")
        patterns.append(re.compile("^" + pat + "$"))
    return patterns


def _split_globs(s):
    """Split comma-separated globs while respecting {a,b} brace groups."""
    result, buf, depth = [], [], 0
    for ch in s:
        if ch == "{":
            depth += 1
            buf.append(ch)
        elif ch == "}":
            depth -= 1
            buf.append(ch)
        elif ch == "," and depth == 0:
            if buf:
                result.append("".join(buf).strip())
                buf = []
        else:
            buf.append(ch)
    if buf:
        result.append("".join(buf).strip())
    return result


def load_rules():
    """Return [(rule_name, [compiled_patterns])]. Empty list if rules dir missing."""
    out = []
    if not RULES_DIR.exists():
        return out
    for f in sorted(RULES_DIR.glob("*.md")):
        text = f.read_text()
        m = re.search(r"^#\s*Glob:\s*(.+)$", text, re.MULTILINE)
        if not m:
            continue
        globs = _split_globs(m.group(1))
        pats = []
        for g in globs:
            pats.extend(_glob_to_regex(g))
        out.append((f.stem, pats))
    return out


def _applicable(path, rules):
    return [name for name, pats in rules if any(p.match(path) for p in pats)]


def _cited(text, names):
    # Phase 2.1 TODO: substring match produces false positives — "add user routes"
    # counts as citing routes.md. Tighten to an anchored form (e.g. "per routes.md"
    # or "routes.md —") before declaring Phase 2 done, otherwise low-effort
    # justifications score higher than they should.
    t = text.lower()
    return [n for n in names if n.lower() in t]


def score_target(target, rules):
    path = target.get("file", "") if isinstance(target, dict) else str(target)
    justification = target.get("justification", "") if isinstance(target, dict) else ""
    if path.startswith(EXEMPT_PREFIXES):
        return {
            "file": path,
            "applicable": [],
            "cited": [],
            "score": 100,
            "exempt": True,
            "flags": ["CWT tooling — exempt from app architecture rules"],
        }
    applicable = _applicable(path, rules)
    cited = _cited(justification, applicable)
    specific = [r for r in applicable if r not in CATCH_ALL]
    specific_cited = [r for r in cited if r not in CATCH_ALL]
    flags = []
    if not specific:
        flags.append("path outside known layers (no specific rules matched)")
        score = 50
    else:
        score = int(100 * len(specific_cited) / len(specific))
        if len(specific_cited) < len(specific):
            missing = [r for r in specific if r not in specific_cited]
            flags.append(f"uncited rules: {', '.join(missing)}")
    return {
        "file": path,
        "applicable": applicable,
        "cited": cited,
        "score": score,
        "flags": flags,
    }


def score_plan(plan):
    rules = load_rules()
    targets = plan.get("targets", []) if isinstance(plan, dict) else []
    per_target = [score_target(t, rules) for t in targets]
    scored = [t["score"] for t in per_target if not t.get("exempt")]
    overall = sum(scored) // len(scored) if scored else None
    return {
        "overall": overall,
        "targets": per_target,
        "rules_loaded": len(rules),
    }
