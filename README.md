<p align="center">
  <h1 align="center">CW Secure Template</h1>
  <p align="center">
    A complete Claude Code project framework.<br>
    Memory, routing, security, deployment. All wired.
  </p>
  <p align="center">
    <a href="https://rpatino-cw.github.io/cw-secure-guide/"><img src="https://img.shields.io/badge/%E2%96%B6%EF%B8%8F_INTERACTIVE_GUIDE-See_it_in_action-ffffff?style=for-the-badge&labelColor=ffffff&color=4f46e5&logoColor=4f46e5" alt="Interactive Guide"></a>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OWASP-10%2F10-22c55e?style=flat-square" alt="OWASP">
  <img src="https://img.shields.io/badge/SOC_2-aligned-3b82f6?style=flat-square" alt="SOC 2">
  <img src="https://img.shields.io/badge/coverage-80%25_gate-f59e0b?style=flat-square" alt="Coverage">
  <img src="https://img.shields.io/badge/Go_%2B_Python-ready-6366f1?style=flat-square" alt="Stacks">
  <img src="https://img.shields.io/badge/AI_slop-0%25_·_S%2B%2B-22c55e?style=flat-square" alt="Zero AI Slop">
  <img src="https://img.shields.io/badge/.claude-full_structure-a855f7?style=flat-square" alt=".claude/">
</p>

```
git clone https://github.com/rpatino-cw/cw-secure-template my-app && cd my-app && bash setup.sh
```

That's it. Claude gets project memory, slash commands, security rules, auto-review skills, and subagent personas. Your app gets auth, secrets, scanning, rate limiting, CI, and deployment configs. All wired. Start building.

---

This isn't just a security template. It's a full Claude Code project setup. When you clone this and run setup, Claude gets everything it needs to work in your project: memory that persists across sessions, slash commands for common tasks, rules that apply automatically based on file type, a security review skill that triggers on code changes, and subagent personas for audits and code review. Your app gets real Okta auth, rate limiting, secret management, CI with coverage gates, and Helm deployment configs. If you try to take a shortcut (hardcoding a key, skipping auth, pasting secrets), the template catches it and shows you the easy way. Check out the **[interactive guide](https://rpatino-cw.github.io/cw-secure-guide/)** to see it all in action.

---

## Your Code Goes Through 6 Checkpoints

Each one catches what the last one missed.

<p align="center">
  <img src="docs/pipeline-animation.svg" alt="Security Pipeline" width="100%">
</p>

---

## Claude Writes Secure Code For You

Even if you ask it not to.

<p align="center">
  <img src="docs/claude-intercept.svg" alt="Claude Intercepts Bad Prompts" width="100%">
</p>

---

## Every Commit Is Checked Automatically

You just write code. The pipeline handles the rest.

<p align="center">
  <img src="docs/commit-flow.svg" alt="Commit Flow" width="100%">
</p>

---

## If Something's Wrong, You'll Know Exactly What To Fix

No cryptic error codes. Plain English.

<p align="center">
  <img src="docs/error-caught.svg" alt="Error Caught — Plain English" width="100%">
</p>

---

## The Lazy Path Is the Secure Path

Every insecure shortcut has a faster secure alternative.

| You want to... | Don't | Do this instead |
|:--|:--|:--|
| Use an API key | Paste it in code or Claude | `make add-secret` (hidden input, straight to .env) |
| Use a config file (.json, .pem) | Drop it in the project folder | `make add-config` (stored in gitignored .secrets/) |
| Use a database URL | Hardcode `postgres://user:pass@...` | `make add-secret` (password goes to .env) |
| Share your .env | Paste it to Claude or Slack | `make add-secret` per value (never paste the whole file) |
| Check for dropped files | Hope for the best | `make doctor` (scans for 20+ dangerous file patterns) |

---

## Full `.claude/` Project Structure

Claude Code reads this folder to understand how to work in your project. Commands, rules, skills, and agents — all security-focused.

```
.claude/
├── settings.json                 Permissions locked (deny force-push, --no-verify, eval)
├── MEMORY.md                     Project memory across sessions
├── commands/
│   ├── check.md                  /project:check — full security suite
│   ├── add-endpoint.md           /project:add-endpoint — secure route scaffold
│   ├── add-secret.md             /project:add-secret — safe key storage
│   └── security-review.md        /project:security-review — 10-point audit
├── rules/
│   ├── security.md               Secrets, auth, validation, dangerous functions
│   ├── testing.md                Coverage, security tests, environment
│   ├── code-style.md             Formatting, logging, imports
│   └── api-conventions.md        REST, status codes, headers
├── skills/
│   └── security-review/SKILL.md  Auto-triggers on code changes
└── agents/
    ├── security-auditor.md       Deep OWASP + CW compliance audit
    └── code-reviewer.md          PR review agent
```

> `settings.json` blocks dangerous commands at the harness level — Claude literally cannot run `--no-verify`, `force-push`, or `eval`. This is structural enforcement, not just instructions.

---

## Get Started

> **First time?** Follow the [step-by-step Getting Started guide](docs/getting-started.md) — it walks you through everything from opening Terminal to running your first app.

Already comfortable with the terminal:

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app
bash setup.sh
make start
```

Setup asks for your **app name, team, and data classification** — then Claude knows your project context in every session. No more generic code.

---

## Personalize It

`make init` turns the generic template into YOUR project. 5 questions, 6 files updated:

| It asks | It updates |
|:--------|:-----------|
| App name | Helm chart, go.mod / pyproject.toml |
| What it does | `.claude/MEMORY.md` (Claude reads this every session) |
| Team name | CODEOWNERS (required PR reviewers) |
| Slack channel | SECURITY.md (incident contacts) |
| Data classification | `.claude/MEMORY.md` (Claude adjusts access controls) |

After init, Claude doesn't generate generic code — it uses your app name for logging, your team for RBAC, and your data sensitivity for access decisions.

---

## 3 Commands

```
make start    Run your app
make check    Before pull requests
make help     Everything else
```

---

## Can't Break It

> In-repo enforcement (hooks, CI, CLAUDE.md, settings.json) works anywhere. Full enforcement requires a [CW org repo](docs/repo-governance.md) with Okta + Doppler configured.

| "I'll just..." | What catches it |
|:--|:--|
| Skip hooks with `--no-verify` | CI checks the timestamp + settings.json blocks the command |
| Delete the security rules | CI blocks the PR |
| Remove the rate limiter | CI middleware check blocks the PR |
| Hardcode a secret | Gitleaks blocks the commit AND the PR |
| Push without tests | Pre-push hook blocks it |
| Commit to main | Branch protection requires a PR |
| Ship without auth | Auth is wired from day 1 |
| Ask Claude to force-push | settings.json deny list blocks it |

---

[Okta OIDC](docs/okta-ticket-template.md) · [Doppler + ESO](docs/doppler-onboarding.md) · [Chainguard images](docs/approved-images.md) · CodeQL · SOC 2 · ISO 27001 · OWASP Top 10

> **Going to production?** Use the [AppSec Review Pack](docs/appsec-review-pack/) and [CW Integration Guide](docs/cw-integration.md).

---

<details>
<summary><b>FAQ</b></summary>
<br>

**Do I need to know security?** No. The template handles it.

**How do I test without Okta?** `DEV_MODE=true` is already set. Works out of the box.

**What if a hook blocks me?** Run `make fix`. It explains everything in plain English.

**How do I get Okta credentials?** File an IT/Freshservice ticket. [Details](CLAUDE.md#okta-app-registration--how-to-get-credentials)

**What's `/project:check`?** A Claude Code slash command. Type it in Claude and it runs the full security suite.

</details>

<details>
<summary><b>What's inside (92 files)</b></summary>
<br>

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
docs/                         Getting started, handbook, AppSec review pack,
                              Okta ticket, Doppler onboarding, approved images
```

</details>

---

<p align="center">
  <sub>Built at CoreWeave · <a href="https://rpatino-cw.github.io/cw-secure-guide/">Interactive Guide</a> · <a href="docs/getting-started.md">Getting Started</a> · <a href="docs/architecture.md">Architecture Diagrams</a> · <a href="docs/security-handbook.md">Security Handbook</a></sub>
</p>
