<p align="center">
  <h1 align="center">CW Vibe</h1>
  <p align="center">
    Plan it. Scaffold it. Ship it secure.<br>
    The app builder for CoreWeave teams using Claude Code.
  </p>
  <p align="center">
    <a href="https://rpatino-cw.github.io/cw-secure-template/"><img src="https://img.shields.io/badge/%E2%96%B6%EF%B8%8F_OPEN_PLATFORM-Plan_%C2%B7_Scaffold_%C2%B7_Ship-ffffff?style=for-the-badge&labelColor=ffffff&color=4f46e5&logoColor=4f46e5" alt="Open CW Vibe Platform"></a>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/8--step-planning_form-6366f1?style=flat-square" alt="8-Step Planning">
  <img src="https://img.shields.io/badge/PLAN.md-generator-22c55e?style=flat-square" alt="PLAN.md Generator">
  <img src="https://img.shields.io/badge/scope_lock-built_in-f59e0b?style=flat-square" alt="Scope Lock">
  <img src="https://img.shields.io/badge/GitHub-best_practices-3b82f6?style=flat-square" alt="GitHub Practices">
  <img src="https://img.shields.io/badge/6--layer-security_pipeline-22c55e?style=flat-square" alt="Security Pipeline">
  <img src="https://img.shields.io/badge/CW_policies-22_enforced-a855f7?style=flat-square" alt="CW Policies">
</p>

---

## What This Is

A platform that helps CW teams — especially DCTs and ops folks — go from idea to deployed app without skipping steps or shipping insecure code.

**Two parts, one repo:**

| Part | What it does |
|:-----|:-------------|
| **[CW Vibe Platform](https://rpatino-cw.github.io/cw-secure-template/)** | Web tool: 8-step planning form, PLAN.md generator, guided terminal tour, pipeline visualization, CW policies reference |
| **Template Code** | Clone it: secure scaffold with auth, hooks, CI, Helm deployment, Claude Code framework (memory, commands, rules, skills, agents) |

The platform helps you plan. The template helps you build. Together they enforce architecture before code, security by default, and good GitHub practices from commit one.

---

## The Platform — Plan Before You Build

Open **[CW Vibe](https://rpatino-cw.github.io/cw-secure-template/)** and walk through 8 steps:

| Step | You Define | PLAN.md Gets |
|:-----|:-----------|:-------------|
| 1. Identity | App name, description, team | Project header |
| 2. Roles | Who uses it, what they can do | Users & RBAC table |
| 3. Schema | Tables, fields, relationships | Database schema |
| 4. Endpoints | API routes, auth, descriptions | API spec table |
| 5. Flow | User journey (auto-generates Mermaid) | Data flow diagram |
| 6. Stack | Language, database, deployment | Stack decisions |
| 7. Infrastructure | Replicas, CPU/memory limits, scaling, environments | Infra config |
| 8. Scope Lock | MVP features, deferred items, GitHub practices, branching | Scope freeze + GitHub rules |

At the end, you get a `PLAN.md` to copy into your project. Claude reads it every session so your whole team stays aligned.

### Scope Lock

Step 8 forces you to define what's in v1 and what's explicitly deferred. The generated PLAN.md includes:

```markdown
## Scope Lock
> Features below are frozen for v1. Do not add scope without team approval.

### MVP (v1)
- [x] CRUD for racks with auth
- [x] Dashboard view

### Deferred (NOT in v1)
- [ ] CSV export
- [ ] Email notifications
```

Claude references this list and resists scope creep during building.

### GitHub Best Practices

Step 8 also locks in your GitHub workflow:

- Branch protection on main
- PR reviews required before merge
- CI must pass before merge
- CODEOWNERS file
- Signed commits (optional)
- Conventional commit messages (optional)
- Branching strategy (feature branches, GitFlow, or trunk-based)

These go into the PLAN.md so Claude enforces them from the first commit.

---

## The Template — Clone and Build

```
git clone https://github.com/rpatino-cw/cw-secure-template my-app && cd my-app && bash setup.sh
```

### What You Get Immediately

| Layer | What's wired |
|:------|:------------|
| **Claude Code** | CLAUDE.md (15 security rules), .claude/ folder (memory, 4 commands, 4 rules, skill, 2 agents), settings.json (dangerous commands blocked) |
| **Pre-commit** | Gitleaks (secret scanning), ruff + bandit (Python), golangci-lint (Go), timestamp tracking |
| **CI Pipeline** | CodeQL, SAST, dependency scanning, 80% coverage gate, hook integrity check |
| **Auth** | Okta OIDC middleware, group-based RBAC, DEV_MODE for local dev |
| **Runtime** | Rate limiting, request ID tracking, security headers, request size limits |
| **Deployment** | Helm chart, ArgoCD, Chainguard images, env-specific values (dev/stg/prod) |

### 3 Commands

```
make start    Run your app
make check    Before pull requests
make help     Everything else
```

### Personalize It

```
make init
```

5 questions → 6 files updated. Claude knows your app name, team, data classification, and Slack channel. No more generic code.

---

## The Pipeline — 6 Layers, No Shortcuts

```
Your Code → CLAUDE.md → Pre-commit → CI Pipeline → PR Review → Deploy
```

| "I'll just..." | What catches it |
|:--|:--|
| Hardcode a secret | Gitleaks blocks the commit |
| Skip auth | CLAUDE.md refuses + auth is wired |
| Use `--no-verify` | CI timestamp check blocks the PR |
| Delete security rules | CI blocks the PR |
| Push without tests | Pre-push hook blocks it |
| Commit to main | Branch protection requires a PR |
| Ask Claude to force-push | settings.json deny list blocks it |

---

## The Guided Tour — 11 Interactive Demos

The [platform](https://rpatino-cw.github.io/cw-secure-template/) includes a guided tour with live terminal simulations:

| # | Demo | What You See |
|:--|:-----|:-------------|
| 1 | The Problem | Same prompt, with vs. without template |
| 2 | Clone & Setup | Full setup from `git clone` to `make start` |
| 3 | Start Your App | Running app with auth, headers, request tracking |
| 4 | Build + Commit + Push | Feature → 6 security checkpoints → PR ready |
| 5 | Claude Blocks Bad Ideas | 3 insecure shortcuts intercepted in real time |
| 6 | Secret Caught | API key blocked at commit with plain English fix |
| 7 | CI Catches --no-verify | Timestamp integrity check blocks the PR |
| 8 | Rate Limiter | 100 req/min per IP, other users unaffected |
| 9 | Safe Secret Storage | `make add-secret` with hidden input |
| 10 | Slash Commands | /check, /add-endpoint, /security-review |
| 11 | Project Init | `make init` personalizes 6 files |

Each stop auto-plays with typing animation and shows a takeaway when complete.

---

## CW Policy Compliance

The platform visualizes 22 CW security policies:

- **Remediation timelines**: Critical (15 days), High (30), Medium (60), Low (90)
- **Data classification**: Public → Internal → Confidential → Restricted
- **8 policy categories**: Authentication, Secrets, Code Security, Data Protection, Access Control, Deployment, Monitoring, SDLC

The template enforces these policies structurally — not as guidelines, as code.

---

## What's Inside (92 files)

<details>
<summary>Expand</summary>

```
CLAUDE.md                     AI security rules (15 rules, anti-jailbreak)
.claude/                      Claude Code project config
  settings.json               Permissions (deny dangerous commands)
  commands/                   4 slash commands (/check, /add-endpoint, etc.)
  rules/                      4 modular rule files (security, testing, style, API)
  skills/                     Auto-review on code changes
  agents/                     Security auditor + code reviewer
security-dashboard.html       Interactive pipeline visual
scripts/                      Git hooks, doctor, fix, quiz, add-secret, add-config
go/                           Go starter + Okta auth middleware + Dockerfile
python/                       Python starter + Okta auth middleware + Dockerfile
deploy/                       Helm chart + ArgoCD + env-specific values
docs/                         Platform site, getting started, handbook, AppSec pack
```

</details>

---

<details>
<summary><b>FAQ</b></summary>
<br>

**What is CW Vibe?** A planning tool + secure scaffold + educational guide for CW teams building internal apps with Claude Code.

**Who is it for?** Anyone at CW — DCTs, ops, engineers — who wants to build an internal tool without worrying about security, GitHub setup, or architecture decisions.

**Do I need to know security?** No. The template handles it.

**What's a PLAN.md?** A markdown file that describes your app's architecture. Claude reads it every session so it knows what you're building, who uses it, and what's in scope.

**How do I test without Okta?** `DEV_MODE=true` is already set. Works out of the box.

**What if a hook blocks me?** Run `make fix`. It explains everything in plain English.

</details>

---

<p align="center">
  <sub>Built at CoreWeave · <a href="https://rpatino-cw.github.io/cw-secure-template/">CW Vibe Platform</a> · <a href="docs/getting-started.md">Getting Started</a> · <a href="docs/security-handbook.md">Security Handbook</a></sub>
</p>
