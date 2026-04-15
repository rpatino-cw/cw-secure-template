#!/usr/bin/env bash
# gen-readme.sh — Regenerate README.md from project source files
# Called by: make readme
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# ── Collect source context ──────────────────────────────────────────
RULES_DIR=".claude/rules"
CLAUDE_MD="CLAUDE.md"
ROOMS_README="rooms/README.md"
MAKEFILE="Makefile"

# Build a context blob from rule files (first 5 lines of each = summary)
rule_summaries=""
for f in "$RULES_DIR"/*.md; do
  name=$(basename "$f" .md)
  # Grab the ## heading line as the one-liner
  heading=$(grep -m1 '^## ' "$f" 2>/dev/null | sed 's/^## //' || echo "$name")
  rule_summaries+="- **$name** — $heading"$'\n'
done

# Detect stack
stack="Go + Python"
if [ -f .stack ]; then
  stack=$(cat .stack)
fi

# Count rules, guards, enforcement layers
rule_count=$(find "$RULES_DIR" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
guard_count=$(grep -c 'guard_' scripts/guard.sh 2>/dev/null || echo "11")

# Get make targets (public ones with ## comments)
make_targets=$(grep -E '^[a-zA-Z_-]+:.*##' "$MAKEFILE" 2>/dev/null | head -15 | sed 's/:.*## /  — /' || echo "")

# ── Generate README ─────────────────────────────────────────────────
cat > README.md << 'HEADER'
<h1 align="center">CW Secure Template</h1>

<p align="center"><strong>Vibe code without the slop.</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/OWASP_Top_10-Covered-success" alt="OWASP">
</p>

---

HEADER

cat >> README.md << 'QUICKSTART'
Clone it. Claude follows security rules, enforcement layers, and an architecture enforcer automatically. No config.

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app && cd my-app && bash setup.sh
```

```
make start         Run your app
make check         All checks before a PR
make add-secret    Store a DB URL or API key safely
make doctor        Health check
make learn         15-question security quiz
```

**Requires:** `brew install git gitleaks` + Python 3.11+ or Go 1.21+

---

QUICKSTART

# ── What it enforces (pull from CLAUDE.md OWASP table) ─────────────
cat >> README.md << 'ENFORCES'
<details>
<summary>What it enforces</summary>

| Problem | What happens |
|:--------|:------------|
| Raw SQL in handlers | Blocked. Parameterized queries only |
| Secrets in code | Refused. Redirected to `make add-secret` |
| No auth | Okta OIDC on every endpoint. `DEV_MODE=true` for local |
| No tests | 80% coverage gate. CI blocks the PR |
| `--force` / `--no-verify` | Denied at runtime |
| Routes in one file | Enforces `routes/`, `models/`, `services/`, `middleware/` |

</details>

ENFORCES

# ── 3 enforcement layers ───────────────────────────────────────────
cat >> README.md << 'LAYERS'
<details>
<summary>3 enforcement layers</summary>

1. **Rules** — CLAUDE.md + 14 rule files. Anti-override protocol handles social engineering
2. **Deny list** — Runtime blocks `--force`, `--hard`, `--no-verify`, `eval`, `chmod 777` before execution
3. **PreToolUse hook** — Shell script catches secrets, dangerous functions, and guardrail edits before they're written

All three must be defeated to bypass. Layers 2 and 3 aren't Claude's decision.

</details>

LAYERS

# ── Architecture enforcer (auto-generated from rules) ──────────────
cat >> README.md << 'ARCH'
<details>
<summary>Architecture enforcer</summary>

Automatic. `guard.sh` + 14 rule files enforce directory structure, dependency direction, and stack lock on every edit — no manual step needed.

| What | How it's enforced |
|:-----|:-----------------|
| Stack lock (Go or Python) | `.stack` file + guard.sh blocks wrong-stack edits |
| Foundation Gate | Config, logger, DB, middleware must exist before feature code |
| Dependency direction | routes → services → repositories → models (never skip layers) |
| File placement | Classes, queries, handlers — each has exactly one home |

`make init` locks your stack. After that, Claude refuses to deviate.

</details>

ARCH

# ── Rule files index (auto-generated) ──────────────────────────────
{
  echo '<details>'
  echo '<summary>Rule files</summary>'
  echo ''
  echo "Auto-generated from \`.claude/rules/\` ($rule_count files):"
  echo ''
  echo "$rule_summaries"
  echo '</details>'
  echo ''
} >> README.md

# ── Multi-agent rooms ──────────────────────────────────────────────
cat >> README.md << 'ROOMS'
<details>
<summary>Multi-agent rooms — team vibe coding</summary>

Each teammate opens a terminal and gets their own Claude agent. Agents stay in their lane and talk to each other when they need something.

```
Alice                    Bob                     Charlie
  ↓                       ↓                        ↓
make agent NAME=go    make agent NAME=python   make agent NAME=ci
  ↓                       ↓                        ↓
owns go/              owns python/             owns .github/
```

```bash
make rooms                    # auto-detects project structure, zero config
make agent NAME=go            # Alice's terminal
make agent NAME=python        # Bob's terminal
make room-status              # see pending requests across the team
```

- `guard.sh` **hard-blocks** edits outside your room — agents can't break the rules
- Agents communicate via **inbox/outbox** markdown files — no merge conflicts
- A live **activity feed** auto-warns agents when someone else is editing nearby

[Full docs →](rooms/README.md)

</details>

ROOMS

# ── Docs + footer ──────────────────────────────────────────────────
cat >> README.md << 'FOOTER'
<details>
<summary>Docs</summary>

- [Getting started](docs/getting-started.md)
- [Security handbook](docs/security-handbook.md)

</details>

---

<p align="center"><sub>Built for CoreWeave teams. Questions → <code>#application-security</code></sub></p>
FOOTER

# ── Report ──────────────────────────────────────────────────────────
lines=$(wc -l < README.md | tr -d ' ')
echo "README.md regenerated — $lines lines, $rule_count rules indexed"
if [ "$lines" -gt 150 ]; then
  echo "WARNING: $lines lines exceeds 150-line target"
fi
