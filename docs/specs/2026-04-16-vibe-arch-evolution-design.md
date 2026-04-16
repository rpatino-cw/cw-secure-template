# Design Spec: vibe-arch — Evolving CW Secure Template into a Team Vibe Coding Framework

> Date: 2026-04-16
> Author: Romeo Patino
> Status: Draft
> Repo: https://github.com/rpatino-cw/cw-secure-template

---

## Summary

Evolve cw-secure-template from a security-focused coding framework into a full team vibe coding platform. Non-technical people build apps with AI. The framework silently enforces architecture, protects files, assigns roles, manages trust levels, and validates quality — so teams ship real software without needing to understand software engineering.

First user: CoreWeave internal teams. Then open-source.

## Problems Solved

1. **Spaghetti code** — AI builds things that work but nobody can maintain or extend. Architecture enforcement and auto-routing fix this.
2. **Broken output** — Looks done but fails under pressure. Quality gates catch this before "done" is claimed.
3. **Can't collaborate** — One person vibes something, another can't pick it up. Rooms, roles, trust tiers, and handoff docs fix this.

## What Already Exists (Don't Touch)

The current cw-secure-template provides:

- 4 security enforcement layers (CLAUDE.md rules, settings.json deny list, guard.sh PreToolUse hooks, config audit gate)
- Anti-override protocol (refuses prompt injection, social engineering, override attempts)
- Room-based multi-agent coordination (6 rooms, file ownership, inbox/outbox messaging)
- Architecture enforcement (stack lock, foundation gate, dependency direction)
- Collaboration rules (anti-overwrite, edit discipline, git awareness)
- 13 auto-loaded rule files (.claude/rules/) covering every code domain
- 31 guard unit tests
- Blueprints (6 scaffold types via `make new`)
- Enforcement profiles (hackathon/balanced/strict/production)
- Adoption tools (`make adopt` for existing projects, `make upgrade` for sync)
- Security dashboard (security-dashboard.html)
- Visualizer (docs/visualizer.html)

**None of this changes.** Everything below is additive.

---

## Feature 1: Trust Tiers

### Purpose
Control how much autonomy each team member gets. New people start restricted. Experienced people get broader access. Leads can touch anything.

### Data Model

New file: `team.json` at project root.

```json
{
  "version": 1,
  "members": {
    "alice": {
      "room": "py-dev",
      "tier": "starter",
      "joined": "2026-04-16"
    },
    "bob": {
      "room": "go-dev",
      "tier": "builder",
      "joined": "2026-03-01"
    },
    "romeo": {
      "room": "security",
      "tier": "lead",
      "joined": "2026-02-15"
    }
  }
}
```

### Tier Definitions

| Tier | Permissions | Restrictions |
|------|------------|-------------|
| **starter** | Edit files in assigned room only. All edits pass through guard. | Cannot create new files outside room. Cannot edit shared files. Cannot approve cross-room requests. Cannot modify team.json, rooms.json, or any guard/rule file. |
| **builder** | Full access within assigned room. Can request cross-room changes via inbox. Can create new files in room. | Cannot edit shared files directly (must request via inbox to approver). Cannot modify framework files. |
| **lead** | All builder permissions plus: edit shared files, approve cross-room requests, modify rooms.json and team.json, run `make profile`, promote/demote members. | Cannot modify guard.sh or CLAUDE.md without PR review (enforced by CODEOWNERS). |

### Identity Model

How the framework knows WHO is making an edit:

- **Multi-agent mode (primary):** Each agent runs via `make agent NAME=py-dev`. The `start-agent.sh` script sets `AGENT_ROOM=py-dev` in the environment. `trust.sh` reads `$AGENT_ROOM` and looks up the member assigned to that room in `team.json`.
- **Solo mode (fallback):** If `$AGENT_ROOM` is not set, `trust.sh` reads `$VIBE_USER` env var. Users set this in `.env` or export it in their shell. If neither is set, the guard warns but does not block (graceful degradation — solo users aren't gated).
- **Important:** This is advisory enforcement at the Claude/hook level, not OS-level kernel enforcement. A determined user can bypass it by editing files directly outside Claude Code. The framework protects against accidental cross-room edits and AI overreach, not malicious actors with shell access.

### Enforcement

New guard module: `scripts/guards/trust.sh`

- Reads `team.json` on every PreToolUse call
- Matches current user via `$AGENT_ROOM` (preferred) or `$VIBE_USER` (fallback)
- Checks tier against the action being attempted
- Returns `exit 2` (hard block) for tier violations
- Returns `stdout` warning for borderline actions
- If no identity found: warn once per session, allow action (don't block solo users)

### Make Commands

| Command | What it does |
|---------|-------------|
| `make join` | Self-selection flow for new members (see Feature 2) |
| `make promote NAME=alice TIER=builder` | Lead promotes a member |
| `make team` | Show current team roster with tiers and rooms |

### Interaction with Existing Systems

- Guard.sh dispatcher calls `trust.sh` before `rooms.sh` — tier check happens first
- Enforcement profiles affect tier strictness: hackathon mode relaxes starter restrictions, production mode tightens them
- The config audit gate (Layer 4) still applies regardless of tier

---

## Feature 2: Role Self-Selection

### Purpose
When someone opens the project for the first time, they pick what they're working on. The framework assigns them to the right room with the right permissions. Zero configuration by the project owner for day-to-day onboarding.

### Flow

```
$ make join

Welcome to [project name].

What are you working on?
  1. Frontend (UI, pages, styles)
  2. Backend — Python (API, services, database)
  3. Backend — Go (API, services, database)
  4. DevOps (CI, Docker, deployment)
  5. Docs (README, guides, onboarding)

Pick a number: 2

You're joining as: py-dev (starter tier)
Your files: python/

To start working:
  make agent NAME=py-dev

A lead can promote you to builder after your first contribution.
```

### Implementation

New script: `scripts/join.sh`

1. Reads `rooms.json` to build the menu dynamically (room descriptions become menu items)
2. Maps selection to room name
3. Writes entry to `team.json` with tier `starter` and current date
4. Prints the room's AGENT.md summary
5. If `team.json` doesn't exist, creates it (first member becomes `lead` automatically)
6. If the wrong person becomes lead by accident, any lead can run `make promote NAME=someone TIER=lead` and `make demote NAME=self TIER=builder` to fix it. Leads can also edit `team.json` directly.

### Edge Cases

- User already in `team.json` → show current assignment, offer to switch rooms
- Room not in `rooms.json` → error with helpful message
- No rooms.json → run `make rooms` first (auto-detection)

---

## Feature 3: Auto-Routing by Complexity

### Purpose
Claude silently picks the right level of planning for each task. No mode commands. No jargon. The user just says what they want.

### Implementation

New rule file: `.claude/rules/routing.md`

```markdown
# Glob: **/*

## Task Routing — Automatic

Before starting any work, silently assess the task scope:

### Signals → Route

**Just do it** (no planning needed):
- Single file change
- Bug fix with obvious location
- Text/copy changes
- Config changes

Action: Edit directly. Run `make check` after.

**Quick plan** (state intent, get ok):
- 2-5 files affected
- Clear scope, no cross-room impact
- Adding a new endpoint or component

Action: State in 2-3 bullets what you'll change and why. Wait for "ok" or
"go ahead" before starting. Run `make check` after. Don't name the routing
tier or announce that you're "using the quick plan route" — just present
the bullets naturally.

**Full plan** (write plan doc, get approval):
- 6+ files affected
- New feature or significant refactor
- Cross-room impact (touching files owned by multiple rooms)
- Changes to shared files (CLAUDE.md, rooms.json, docker-compose.yml)
- User explicitly says "plan this" or "think about this first"

Action: Write plan to `.plans/{feature-name}.md` with: what changes, which
files, which rooms affected, what to test. Present to user. Wait for explicit
approval. Build step by step. Run `make check` after each step.

**Coordination required** (multi-room):
- Task requires changes in 2+ rooms
- Detected by checking target files against rooms.json

Action: Write inbox requests to affected rooms. Wait for responses. Then
proceed with the approved plan.

### Rules
- Don't name the routing tier or say "I'm using the full plan route." Just do it naturally — present bullets for medium tasks, write a plan doc for big ones.
- When in doubt, go one level up (quick plan instead of just do it).
- Always run `make check` at the end regardless of route.
```

### No New Scripts Needed

This is purely a Claude rule — no guard enforcement. The guard already blocks cross-room edits, which naturally forces coordination. The routing rule adds planning discipline on top.

---

## Feature 4: Quality Gates

### Purpose
Extend guard.sh beyond security to catch quality problems before code ships.

### Implementation

New guard module: `scripts/guards/quality.sh`

Called by guard.sh dispatcher on PostToolUse (after edits, not before).

### Checks

| Check | When | Severity |
|-------|------|----------|
| Source file has no matching test file | After writing to services/, routes/, repositories/ | warn (hackathon), block (production) |
| File exceeds 300 lines | After any write | warn |
| TODO without ticket number | After any write | warn |
| `make check` not run before claiming done | Before commit | block |
| New endpoint missing auth middleware | After writing to routes/ | block (all profiles) |

### Detection Strategy (v1 — file-level, not function-level)

For "source file has no matching test file":
```bash
# Given: user edited python/src/services/user_service.py
# Check: does tests/test_user_service.py OR tests/services/test_user_service.py exist?
# Pattern: strip src path prefix, prepend tests/, prepend test_ to filename
```

Function-level coverage detection is out of scope for v1. File-level is cheap, reliable, and catches 80% of the problem.

### Two Invocation Modes

1. **Guard-time (per-file, advisory):** `quality.sh` runs via PostToolUse after each edit. Checks the single file just written. Warns but does not block (guard hooks are advisory on PostToolUse).
2. **Full-scan (blocking):** `make check` runs `quality.sh --full-scan` across the whole codebase. This is the blocking gate before push.

### Profile-Aware

```bash
# In quality.sh
PROFILE=$(cat .enforcement-profile 2>/dev/null || echo "balanced")

case "$PROFILE" in
  hackathon)  MISSING_TEST_ACTION="warn" ;;
  balanced)   MISSING_TEST_ACTION="warn" ;;
  strict)     MISSING_TEST_ACTION="block" ;;
  production) MISSING_TEST_ACTION="block" ;;
esac
```

### Make Command

`make check` already runs lint + test + security-scan. Add quality checks:

```makefile
check: lint test security-scan quality-check
```

New target `quality-check` runs `scripts/guards/quality.sh --full-scan` which checks the entire codebase rather than a single file.

---

## Feature 5: Team Dashboard

### Purpose
Visual overview of who's working where, project health, and file protection. Replaces the current security-only dashboard with a full team view.

### Implementation

Evolve `security-dashboard.html` → `team-dashboard.html` (keep security dashboard as-is for backward compatibility).

### Sections

1. **Team roster** — reads `team.json`, shows members with rooms and tiers. Color-coded by room.
2. **File protection map** — reads `rooms.json`, renders a directory tree with room ownership highlighted. Shared files marked distinctly.
3. **Activity feed** — reads `rooms/activity.md`, shows recent edits with timestamps and room colors.
4. **Inbox queue** — reads all `rooms/*/inbox/` dirs, shows pending cross-room requests.
5. **Project health** — runs `make check --json` (new flag), shows test coverage, lint status, guard test results, open TODOs.
6. **Trust overview** — breakdown of team by tier, join dates, promotion history.

### Technical

- Single HTML file with embedded JS (no build step, no dependencies)
- Reads project files via fetch() when served locally, or via static snapshots
- Refreshes on interval (5s) when running via `make dashboard`
- Mobile-responsive for checking on phone

### Make Command

```makefile
dashboard: ## Open team dashboard
    @bash scripts/serve-dashboard.sh
```

`serve-dashboard.sh` generates a `dashboard-data.json` snapshot (team.json + rooms.json + activity.md + make check results), copies it alongside `team-dashboard.html` into a temp directory, then serves only that directory on `127.0.0.1:8090`. No source code, `.env`, or other project files are exposed.

---

## Feature 6: Archon Workflow Pack

### Purpose
Optional deterministic pipelines for L/XL features. Teams that install Archon get fire-and-forget workflows. Teams that don't still have the full framework.

### Workflows

Stored in `.archon/workflows/` within the template.

#### vibe-arch-feature

```
explore (interactive loop) → plan → implement (task-by-task loop) → validate (make check) → review → PR
```

Requires Archon >= 0.3.0 (YAML DAG workflow format). Based on archon-piv-loop but adapted:
- Plan node reads rooms.json and scopes work to the user's room
- Implement node respects trust tier (starter gets more validation hooks)
- Validate node runs `make check`, not bun-specific commands
- Review node checks architecture rules compliance

#### vibe-arch-review

```
3 parallel agents → synthesize → fix
```

Three review agents run simultaneously:
- Security reviewer (reads CLAUDE.md absolute rules)
- Architecture reviewer (reads .claude/rules/architecture.md)
- Quality reviewer (reads .claude/rules/ for the relevant file types)

Synthesize node merges findings, deduplicates, prioritizes.

#### vibe-arch-onboard

Interactive workflow for new team members:
```
welcome → pick role (make join) → first task (guided) → review → promote to builder
```

Walks someone through their first contribution with extra guardrails and explanations.

### Installation

```makefile
archon-setup: ## Install Archon workflows (optional)
    @mkdir -p .archon/workflows
    @cp templates/archon/*.yaml .archon/workflows/
    @echo "  Archon workflows installed. Run: archon workflow list"
```

### Dependency

Archon is optional. If not installed, `make archon-setup` prints installation instructions. All other features work without it.

---

## Feature 7: CLI / npx Init

### Purpose
Open-source adoption. Anyone can scaffold a vibe-arch project without cloning the template.

### Usage

```bash
npx vibe-arch init
```

### Flow

```
vibe-arch — Team Vibe Coding Framework

Project name: my-app
Stack: (1) Python  (2) Go  (3) Both
Team size: (1) Solo  (2) Small (2-5)  (3) Large (6+)
Enforcement: (1) Hackathon  (2) Balanced  (3) Strict  (4) Production

Scaffolding...
  Created .claude/rules/ (13 files)
  Created .claude/settings.json (deny list)
  Created scripts/guard.sh (4 modules)
  Created rooms.json (auto-detected)
  Created team.json (you're the lead)
  Created Makefile
  Created .gitignore
  Created CLAUDE.md

Done. Run:
  make help     — see available commands
  make join     — add team members
  make start    — run your app
```

### Technical

- npm package: `vibe-arch`
- Single entry point: `bin/vibe-arch.js`
- Copies template files from `templates/` directory in the package
- Replaces placeholder values (project name, stack choice)
- Runs `make rooms` to auto-detect structure
- Sets first user as lead in team.json

### Phasing

This ships LAST. The template repo is the source of truth. The CLI packages the template for distribution. Build the features in the template first, package as CLI after they're stable.

---

## Build Order

| Phase | Features | Estimated Effort |
|-------|----------|-----------------|
| **Phase 1** | Trust tiers (team.json + trust.sh guard) + Role self-selection (make join) | M |
| **Phase 2** | Auto-routing rule + Quality gates (quality.sh guard) | S |
| **Phase 3** | Team dashboard (team-dashboard.html) | M |
| **Phase 4** | Archon workflow pack (3 workflows) | L |
| **Phase 5** | CLI / npx init | M |

Each phase ships independently. Phase 1 is the foundation — tiers and roles must exist before routing and quality can reference them.

---

## Success Criteria

- [ ] A new team member can run `make join`, pick a role, and start building within 5 minutes
- [ ] A starter-tier member physically cannot edit files outside their room
- [ ] Claude auto-plans features that touch 6+ files without being asked
- [ ] `make check` catches missing tests, lint issues, and security problems before push
- [ ] Team dashboard shows who's working where and project health at a glance
- [ ] All existing guard tests still pass (31/31)
- [ ] Enforcement profiles control quality gate strictness
- [ ] Framework works fully without Archon installed

## Anti-Patterns (Do NOT)

- Don't require users to learn commands, modes, or jargon — everything is invisible or menu-driven
- Don't break existing make commands or guard behavior
- Don't add dependencies that require npm/pip install for the core framework (bash + python3 only)
- Don't build the CLI before the template features are stable
- Don't make Archon required — it's an optional power-up
- Don't add config files that users need to understand — team.json and rooms.json are the only ones, and both are auto-generated
