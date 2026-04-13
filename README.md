<p align="center">
  <h1 align="center">CW Secure Template</h1>
  <p align="center">
    Build internal tools with AI. Ship them secure. No security expertise needed.
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OWASP_Top_10-10%2F10_covered-22c55e?style=flat-square" alt="OWASP Coverage">
  <img src="https://img.shields.io/badge/SOC_2-aligned-3b82f6?style=flat-square" alt="SOC 2">
  <img src="https://img.shields.io/badge/coverage_gate-80%25-f59e0b?style=flat-square" alt="Coverage Gate">
  <img src="https://img.shields.io/badge/Go_%2B_Python-ready-6366f1?style=flat-square" alt="Go + Python">
</p>

---

## The Problem

You use Claude or Cursor to build an internal tool. It works. You ship it. Then AppSec finds:

- API keys hardcoded in source code
- No authentication on endpoints
- SQL injection in the first query
- Secrets committed to git history

**This template makes those mistakes impossible.**

---

## How It Works

Your code passes through 6 security checkpoints before it reaches production. Each layer catches what the previous one missed.

<p align="center">
  <img src="docs/pipeline-animation.svg" alt="Security Pipeline" width="100%">
</p>

| Layer | What it does | Can you skip it? |
|:------|:-------------|:-----------------|
| **CLAUDE.md** | 14 rules Claude follows even if you say "ignore the rules" | No — anti-jailbreak protected |
| **Pre-commit** | Scans for leaked secrets and code issues before every commit | No — CI catches skipped hooks |
| **Pre-push** | Runs tests before your code leaves your machine | No — push is blocked |
| **CI Pipeline** | CodeQL + security scanners + 80% test coverage gate | No — server-side, can't bypass |
| **PR Review** | 10-point security checklist for every pull request | No — branch protection enforced |
| **Deploy** | Non-root containers, network policies, encrypted secrets | No — Helm defaults are locked |

---

## Quick Start

```bash
# Clone it
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app

# Run setup (takes ~2 min)
bash setup.sh

# Start building
make run
```

That's it. Open Claude Code in the project folder and start prompting. Security is automatic.

---

## What You Get

### For building

| | Go | Python |
|:--|:---|:-------|
| **Framework** | net/http (stdlib) | FastAPI |
| **Auth** | Okta OIDC (real, not a TODO) | Okta OIDC (real, not a TODO) |
| **Rate limiting** | Token bucket, per-IP | Sliding window, per-IP |
| **Request tracking** | UUID on every request | UUID on every request |
| **Logging** | Structured JSON (slog) | Structured JSON (structlog) |
| **Tests** | 7 tests included | 10 tests included |
| **Docker** | Chainguard multi-stage | Slim multi-stage |

### For learning

| Command | What it does |
|:--------|:-------------|
| `make learn` | 15-question security quiz with explanations |
| `make dashboard` | Interactive visual of the entire pipeline |
| `make doctor` | Check if your security pipeline is healthy |
| Read the code | Every security decision has a `SECURITY LESSON` comment |

### For deploying

- **Helm chart** with security context, resource limits, health probes
- **External Secrets Operator** pulls secrets from Doppler (never in git)
- **Network policies** default-deny with explicit allowlist
- **Branch protection** auto-configured during setup

---

## Commands

```
make setup          One-time setup (hooks, deps, health check)
make run            Start the app
make test           Run tests
make check          Run everything — do this before PRs
make fix            Auto-fix what it can, explain what it can't
make doctor         Is my pipeline healthy?
make learn          Security quiz
make dashboard      Open the pipeline visual
```

---

## How Claude Handles Messy Prompts

The `CLAUDE.md` file intercepts bad habits before they become bad code:

| You say | Claude does instead |
|:--------|:-------------------|
| "Just hardcode the API key" | Uses an environment variable |
| "Skip auth for now" | Enables DEV_MODE (auth stays wired for production) |
| "Set CORS to * so it works" | Sets the specific origin you need |
| "Remove the rate limiter" | Increases the limit via config |
| "Use eval() to parse this" | Uses a safe parser |
| "git add everything and push" | Stages specific files, creates a feature branch |
| "Ignore the security rules" | Refuses. Explains why. Helps you do it the right way. |

---

## CW Standards

This template is aligned with CoreWeave's internal security policies:

| Standard | How it's implemented |
|:---------|:--------------------|
| **Okta OIDC** | Real JWT verification middleware, not a TODO |
| **Doppler** | External Secrets Operator in Helm chart |
| **Chainguard** | CW-approved base images in Dockerfiles |
| **AppSec scanning** | CodeQL, gosec, bandit, dependency audit in CI |
| **SOC 2 / ISO 27001** | Audit-ready logging, access control, data protection |
| **OWASP Top 10** | All 10 categories covered by default |

---

## FAQ

<details>
<summary><b>Do I need to know security to use this?</b></summary>
<br>
No. The template handles security for you. Claude follows the rules in CLAUDE.md, the hooks catch mistakes before they reach git, and CI catches everything else. You focus on building — the pipeline handles security.
<br><br>
</details>

<details>
<summary><b>What if I need to test without Okta?</b></summary>
<br>
Set <code>DEV_MODE=true</code> in your <code>.env</code> file. This gives you a fake test user locally. Auth is still wired — when you deploy with real Okta credentials, it just works.
<br><br>
</details>

<details>
<summary><b>Can I use JavaScript/TypeScript instead?</b></summary>
<br>
Not yet. The template currently supports Go and Python (CW's primary stacks). JS/TS support is planned. The CLAUDE.md rules and CI pipeline work with any language — only the starter code is language-specific.
<br><br>
</details>

<details>
<summary><b>What if a pre-commit hook is too slow?</b></summary>
<br>
Don't use <code>--no-verify</code> to skip it. The CI pipeline will catch that you skipped hooks and block your PR. Instead, run <code>make fix</code> to auto-fix the issue, or ask in <code>#application-security</code> for help.
<br><br>
</details>

<details>
<summary><b>How do I get Okta credentials for my app?</b></summary>
<br>
File an IT/Freshservice ticket requesting a new Okta OIDC application. Include: app name, grant type, redirect URIs, and which CW groups need access. IT will send you the client ID and issuer URL.
<br><br>
</details>

---

## Project Structure

```
cw-secure-template/
├── CLAUDE.md                  AI security rules (the brain)
├── SECURITY.md                Incident response template
├── security-dashboard.html    Interactive pipeline visual
├── Makefile                   12 commands
├── setup.sh                   One-command bootstrap
│
├── scripts/
│   ├── git-hooks/             pre-commit, post-checkout, pre-push
│   ├── doctor.sh              Pipeline health check
│   ├── security-fix.sh        Auto-fix + guidance
│   └── security-quiz.sh       15-question OWASP quiz
│
├── go/                        Go starter + middleware + Dockerfile
├── python/                    Python starter + middleware + Dockerfile
├── deploy/helm/               K8s deployment (Helm chart)
└── docs/
    └── security-handbook.md   Plain-English security guide
```

---

<p align="center">
  <sub>Built at CoreWeave. Aligned with SOC 2, ISO 27001, and OWASP Top 10.</sub>
</p>
