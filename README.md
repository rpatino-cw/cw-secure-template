<h1 align="center">CW Secure Template</h1>

<p align="center">
  <strong>Vibe code without the slop.</strong>
</p>

<p align="center">
  <a href="https://rpatino-cw.github.io/cw-secure-template/"><img src="https://img.shields.io/badge/Platform-Open-4f46e5?style=for-the-badge" alt="Platform"></a>
  <a href="docs/getting-started.md"><img src="https://img.shields.io/badge/Docs-Getting_Started-10b981?style=for-the-badge" alt="Docs"></a>
  <a href="docs/security-handbook.md"><img src="https://img.shields.io/badge/Handbook-Security-f59e0b?style=for-the-badge" alt="Security Handbook"></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Python-3.11+-3776AB?logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/Go-1.21+-00ADD8?logo=go&logoColor=white" alt="Go">
  <img src="https://img.shields.io/badge/OWASP_Top_10-Covered-success" alt="OWASP">
  <img src="https://img.shields.io/badge/License-Internal-lightgrey" alt="License">
</p>

---

<p align="center">
  <img src="docs/screenshots/guardrails.gif" alt="Guardrails — messy prompts in, clean code out" width="280">
</p>

You prompt Claude to build an app. It generates spaghetti — routes everywhere, raw SQL, no auth, no tests. You prompt again and it overwrites what it just wrote. Three sessions later, AI slop.

**This template makes that impossible.** Claude follows enforced rules for file structure, database access, API design, and security. You build at full speed. The app stays organized, secure, and ready to scale — even after 100 prompts.

<br>

<p align="center">
  <img src="docs/terminal/demo-typing.svg" alt="Terminal: clone, setup, and start in seconds" width="720">
</p>

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app && bash setup.sh
```

One question — Python or Go. Then you're building.

<br>

## What It Enforces

| Problem | What Claude does in this project |
|:--------|:-------------------------------|
| Routes dumped in one file | Enforces `routes/`, `models/`, `services/`, `middleware/` separation |
| Raw SQL in handlers | Blocks it. Parameterized queries only. Every time |
| Database creds in code | Refuses. Redirects to `make add-secret` (hidden input, `.env`, never committed) |
| Passwords stored plain text | Adds bcrypt/argon2 hashing automatically |
| No auth | Every endpoint gets auth middleware. `DEV_MODE=true` for local testing |
| No tests | 80% coverage gate. 3 test cases per endpoint minimum. CI blocks the PR if missing |
| No input validation | POST/PUT require validated schemas. Raw request bodies rejected |
| Code gets overwritten | `--force`, `--hard`, `--no-verify` all denied. Dropped file detection on every PR |
| Skipped steps | Auth, validation, tests, error handling, headers, rate limiting — all required. Can't skip |
| AI slop | CI runs slop detectors. Boilerplate, redundant wrappers, and junk comments get flagged |

<br>

## 3 Commands. That's It.

<p align="center">
  <img src="docs/terminal/commands.svg" alt="The 3 commands: make start, make check, make add-secret" width="720">
</p>

<br>

## Claude Catches Mistakes and Teaches You Why

<p align="center">
  <img src="docs/terminal/claude-teaches.svg" alt="Claude blocks bad code, explains why, and fixes it automatically" width="720">
</p>

<br>

## Vibe Code With Your Team

<p align="center">
  <img src="docs/terminal/teams.svg" alt="3 people, 3 prompts, 1 consistent codebase" width="720">
</p>

<br>

## What's Already Built

<p align="center">
  <img src="docs/terminal/whats-included.svg" alt="9 features included — zero config" width="720">
</p>

<br>

## Requirements

`brew install git gitleaks` and Python 3.11+ or Go 1.21+. [Full setup guide](docs/getting-started.md).

---

<p align="center">
  <sub>Built for teams that ship fast and sleep well. Questions? <code>#application-security</code> on Slack.</sub>
</p>
