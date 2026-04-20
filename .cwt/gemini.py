"""
Minimal Gemini REST wrapper — stdlib only.

Reads API key from:
  1. $GEMINI_API_KEY environment variable
  2. ~/.config/keys/global.env (shell-export or KEY=VALUE format)
  3. ~/.cwt-secrets/gemini-key (plain text, single line)

Returns None from every function if no key or any failure — callers must
handle the None case gracefully (the whole CWT "one-step" flow is designed
to work without Gemini, just with rule-based fallbacks).

Used by:
  - scripts/cwt-new-server.py (architecture suggestions + name generation)
  - .cwt/server.py /api/explain-plan endpoint (plain-English summaries)
"""

import json
import os
import re
import urllib.request
import urllib.error
from pathlib import Path

MODEL = "gemini-2.5-flash"
ENDPOINT = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
TIMEOUT_SECONDS = 20


def _read_key():
    """Look for the API key in env, then known config paths."""
    v = os.environ.get("GEMINI_API_KEY") or os.environ.get("GEMINI_KEY")
    if v and v.strip():
        return v.strip()
    for p in (Path.home() / ".config" / "keys" / "global.env",
              Path.home() / ".cwt-secrets" / "gemini-key"):
        if not p.exists():
            continue
        try:
            text = p.read_text()
        except Exception:
            continue
        # single-line key file
        if p.name == "gemini-key":
            v = text.strip()
            if v:
                return v
            continue
        # env-style file
        for line in text.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            m = re.match(r"^(?:export\s+)?(GEMINI_API_KEY|GEMINI_KEY)\s*=\s*(.+?)\s*$", line)
            if m:
                val = m.group(2).strip().strip('"').strip("'")
                if val:
                    return val
    return None


def is_available():
    """Cheap check — does a key exist?"""
    return _read_key() is not None


def generate(prompt, system=None, max_tokens=512):
    """Send a prompt to Gemini, return text or None on any failure."""
    key = _read_key()
    if not key:
        return None
    body = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.6,
            "maxOutputTokens": int(max_tokens),
            # Disable "thinking" tokens on Flash — our calls are non-reasoning and
            # thinking tokens eat the maxOutputTokens budget before any text is produced.
            "thinkingConfig": {"thinkingBudget": 0},
        },
    }
    if system:
        body["system_instruction"] = {"parts": [{"text": system}]}
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        f"{ENDPOINT}?key={key}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT_SECONDS) as resp:
            parsed = json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError, json.JSONDecodeError):
        return None
    except Exception:
        return None
    try:
        return parsed["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError, TypeError):
        return None


def suggest_architectures(description):
    """Return a list of 3 architecture candidates for a project description.

    Each candidate: {label, why, stack, suggested_name}.
    Returns None if Gemini is unavailable or the response can't be parsed.
    """
    if not description or not description.strip():
        return None
    system = (
        "You are a software architect helping a non-developer pick how to build their idea. "
        "Given a user's project description, propose 3 concrete architectures. Each must be "
        "something that can be scaffolded as a standalone project on macOS. "
        "Respond ONLY with a JSON array of exactly 3 objects. Each object has keys: "
        '"label" (2-5 words, human-readable), "why" (1 sentence, plain English, when to pick this), '
        '"stack" (short tech list, e.g. "argparse + csv"), "suggested_name" (kebab-case, 2-4 words, no spaces). '
        "Do not wrap in markdown fences. Do not include commentary. JSON only."
    )
    text = generate(description, system=system, max_tokens=600)
    if not text:
        return None
    # Strip markdown fences if Gemini ignored instructions
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip(), flags=re.MULTILINE)
    try:
        items = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(items, list) or len(items) < 1:
        return None
    out = []
    for it in items[:3]:
        if not isinstance(it, dict):
            continue
        label = str(it.get("label", "")).strip()
        why = str(it.get("why", "")).strip()
        stack = str(it.get("stack", "")).strip()
        name = str(it.get("suggested_name", "")).strip().lower()
        name = re.sub(r"[^a-z0-9]+", "-", name).strip("-")
        if not (label and name):
            continue
        out.append({
            "label": label[:60],
            "why": why[:200],
            "stack": stack[:80],
            "suggested_name": name[:40] or "new-project",
        })
    return out or None


def suggest_wizard_selections(description):
    """Recommend wizard selections for a described project.

    Returns {archetype, stack, database, api_shape, why, custom_suggestion?}
    or None if Gemini is unavailable or the response can't be parsed.

    Keys are the wizard's canonical identifiers (e.g. 'backend-api', 'python').
    If Gemini thinks no existing option fits, it returns 'custom' for that field
    and fills in custom_suggestion: {field, label, why}.
    """
    if not description or not description.strip():
        return None
    system = (
        "You recommend wizard selections for a project scaffold. "
        "Respond ONLY with a JSON object (no markdown, no commentary). Keys:\n"
        '  "archetype": one of ["backend-api", "fullstack", "frontend", "cli", "data", "bare"]\n'
        '  "stack": one of ["python", "go", "node"]\n'
        '  "database": one of ["postgres", "sqlite", "none", "redis", "mongo"]\n'
        '  "api_shape": one of ["rest", "graphql", "grpc", "none"]\n'
        '  "why": one sentence explaining the overall recommendation\n'
        "Map the user's description to the closest existing option — do not invent new values. "
        "If the idea is a CLI tool, api_shape must be 'none'. If stateless, database must be 'none'. "
        "If the idea genuinely doesn't fit any existing stack, set stack to the closest and add the "
        "phrase 'consider custom:' at the start of why (e.g. 'consider custom: Rust would fit better')."
    )
    text = generate(description, system=system, max_tokens=400)
    if not text:
        return None
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip(), flags=re.MULTILINE)
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict):
        return None
    valid = {
        "archetype": {"backend-api", "fullstack", "frontend", "cli", "data", "bare"},
        "stack": {"python", "go", "node"},
        "database": {"postgres", "sqlite", "none", "redis", "mongo"},
        "api_shape": {"rest", "graphql", "grpc", "none"},
    }
    out = {"why": str(data.get("why", "")).strip()[:240]}
    for key, allowed in valid.items():
        val = str(data.get(key, "")).strip().lower()
        out[key] = val if val in allowed else None
    return out


def explain_plan(plan_data):
    """Summarize a plan's JSON for a non-developer. Returns text or None."""
    if not isinstance(plan_data, dict):
        return None
    summary = plan_data.get("summary") or ""
    prompt_text = plan_data.get("prompt") or ""
    targets = plan_data.get("targets") or []
    targets_compact = [
        {
            "file": (t.get("file") if isinstance(t, dict) else str(t)),
            "op": (t.get("op") if isinstance(t, dict) else "edit"),
        }
        for t in targets
    ]
    system = (
        "You explain software plans to non-developers. Write 2-4 short sentences. "
        "Plain English — avoid jargon (no 'repository', 'middleware', 'Pydantic', 'endpoint' — "
        "say 'database helper', 'security layer', 'data shape', 'web address'). "
        "Tell the reader what the app WILL DO after this plan is built, not what files change. "
        "No markdown, no bullet points, just prose."
    )
    prompt = (
        f"Original request from the user: {prompt_text!r}\n\n"
        f"Plan summary: {summary}\n\n"
        f"Files the plan will touch ({len(targets_compact)} total): "
        f"{json.dumps(targets_compact)[:800]}\n\n"
        "Explain to a non-developer: what will this change DO for the user once built? "
        "Keep it under 4 sentences."
    )
    return generate(prompt, system=system, max_tokens=220)


def slug_fallback(description):
    """Rule-based project name when Gemini is unavailable.

    "build a tool that counts rows per user" -> "tool-counts-rows"
    Picks up to 4 meaningful words, kebab-cases them, max 40 chars.
    """
    if not description:
        return "new-project"
    stop = {
        "a", "an", "the", "i", "want", "to", "build", "make", "create",
        "my", "some", "something", "that", "this", "for", "of", "in",
        "on", "with", "and", "or", "app", "tool", "one", "is", "it",
    }
    words = re.findall(r"[a-zA-Z0-9]+", description.lower())
    kept = [w for w in words if w not in stop and len(w) > 2][:4]
    if not kept:
        kept = words[:3] or ["new-project"]
    slug = "-".join(kept)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug[:40] or "new-project"
