<p align="center">
  <h1 align="center">CW Secure Template</h1>
  <p align="center">
    Build internal tools with AI. Ship them secure.<br>
    No security expertise needed.
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OWASP-10%2F10-22c55e?style=flat-square" alt="OWASP">
  <img src="https://img.shields.io/badge/SOC_2-aligned-3b82f6?style=flat-square" alt="SOC 2">
  <img src="https://img.shields.io/badge/coverage-80%25_gate-f59e0b?style=flat-square" alt="Coverage">
  <img src="https://img.shields.io/badge/Go_%2B_Python-ready-6366f1?style=flat-square" alt="Stacks">
</p>

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

## Get Started

> **First time?** Follow the [step-by-step Getting Started guide](docs/getting-started.md) — it walks you through everything from opening Terminal to running your first app.

Already comfortable with the terminal:

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app
bash setup.sh
make start
```

---

## 3 Commands

```
make start    Run your app
make check    Before pull requests
make help     Everything else
```

---

## Can't Break It

> In-repo enforcement (hooks, CI, CLAUDE.md) works anywhere. Full enforcement requires a [CW org repo](docs/repo-governance.md) with Okta + Doppler configured.

| "I'll just..." | What catches it |
|:--|:--|
| Skip hooks with `--no-verify` | CI checks the timestamp |
| Delete the security rules | CI blocks the PR |
| Remove the rate limiter | CI middleware check blocks the PR |
| Hardcode a secret | Gitleaks blocks the commit AND the PR |
| Push without tests | Pre-push hook blocks it |
| Commit to main | Branch protection requires a PR |
| Ship without auth | Auth is wired from day 1 |

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

</details>

<details>
<summary><b>What's inside</b></summary>
<br>

```
CLAUDE.md                  AI security rules
security-dashboard.html    Interactive pipeline visual
scripts/                   Git hooks, doctor, fix, quiz
go/                        Go starter + Okta auth middleware
python/                    Python starter + Okta auth middleware
deploy/helm/               K8s deployment
docs/                      Getting started + security handbook
```

</details>

---

<p align="center">
  <sub>Built at CoreWeave · <a href="docs/getting-started.md">Getting Started</a> · <a href="docs/security-handbook.md">Security Handbook</a></sub>
</p>
