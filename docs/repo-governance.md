# Repo Governance

Where production repos should live, what the org provides for free, and how this template fits in.

---

## The Rule

Production internal tools at CoreWeave **must** live in an approved CW GitHub organization. Personal GitHub accounts and personal forks are for prototyping only.

---

## Why This Matters

When a repo lives inside the CW GitHub org, it inherits security controls that are enforced at the organization level:

| Control | What it does |
|---------|-------------|
| **SSO enforcement** | Only users authenticated through CW's Okta SSO can access org repos |
| **Branch protection** | `main` requires PR reviews, status checks, and no force pushes |
| **Secret scanning** | GitHub automatically detects and alerts on committed secrets (API keys, tokens, passwords) |
| **Dependabot** | Automated dependency vulnerability alerts and PR-based updates |
| **GHAS (GitHub Advanced Security)** | CodeQL semantic analysis, security alerts dashboard, code scanning |
| **CODEOWNERS enforcement** | PRs to protected paths require approval from designated owners |
| **Audit logging** | All repo access, clones, and admin actions are logged centrally |

None of these controls apply to repos in personal accounts. A personal repo has no branch protection by default, no secret scanning alerts routed to the security team, and no SSO — anyone with the URL can attempt access.

---

## How to Create a Production Repo

### Option 1: `cw repo create` (preferred)

```bash
cw repo create --name my-service --org coreweave --private
```

This creates the repo with:
- CODEOWNERS file linked to your team
- Default branch protection rules
- Backstage catalog entry
- Standard CI workflows

### Option 2: IT request

If you do not have the `cw` CLI or need a repo with non-standard settings:

1. File an IT ticket in Freshservice.
2. Request: "New GitHub repository in [org-name]"
3. Include: repo name, team, visibility (private/internal), and any non-default settings.

---

## Where This Template Fits

This template repo (`rpatino-cw/cw-secure-template`) is a **personal prototype**. It lives in a personal CW-affiliated account for development and iteration purposes. It is not a production deployment target.

When you use this template to build an actual internal tool:

1. Create the production repo in the official CW org using `cw repo create`.
2. Copy the security layers from this template into the new repo (see [CW Integration Guide](cw-integration.md)).
3. Develop and deploy from the org repo.
4. Do not deploy from a fork of this template in a personal account.

---

## What the Org Gives You for Free

These are automatic and require no configuration on your part:

| Feature | Coverage |
|---------|----------|
| **CODEOWNERS enforcement** | PRs touching protected paths require approval from designated reviewers |
| **Required reviewers** | At least 1 approval required before merge (configurable per repo) |
| **Dependabot alerts** | Notifies you of known vulnerabilities in dependencies |
| **Dependabot security updates** | Auto-opens PRs to bump vulnerable dependencies |
| **Secret scanning** | Detects 200+ secret patterns (AWS keys, GitHub tokens, Slack tokens, etc.) |
| **Push protection** | Blocks pushes that contain detected secrets before they land in git history |
| **GHAS CodeQL** | Semantic code analysis for common vulnerability patterns (SQL injection, XSS, etc.) |
| **Audit log** | Central record of who accessed, cloned, or modified the repo |

---

## What This Template Adds on Top

The org controls are passive — they scan and alert. This template adds active prevention and developer-facing guardrails:

| Layer | What it does | Org provides? |
|-------|-------------|---------------|
| **CLAUDE.md** | Constrains AI-generated code to follow CW security standards | No |
| **Pre-commit hooks** | Blocks secrets, linting failures, and insecure patterns before `git commit` | No |
| **Pre-push hooks** | Runs test suite and coverage check before `git push` | No |
| **Middleware presence checks** | CI verifies that auth, CORS, rate-limit, and request-ID middleware exist in code | No |
| **80% coverage gate** | CI fails if test coverage drops below 80% | No |
| **Security dashboard** | Visual overview of repo security posture for non-technical stakeholders | No |
| **Security quiz** | Interactive training that teaches developers why each guardrail exists | No |
| **Operational docs** | Okta ticket templates, Doppler onboarding, approved images, this governance guide | No |

The org controls and this template are complementary. The org catches what slips past the template. The template prevents issues from reaching git in the first place.

---

## Checklist: Moving a Prototype to Production

When graduating a personal-account prototype to the official org:

- [ ] Create the production repo in the CW org via `cw repo create`
- [ ] Push code to the new repo (do not transfer — start clean to avoid carrying personal-account settings)
- [ ] Verify branch protection is active on `main`
- [ ] Verify Dependabot alerts are enabled (should be automatic)
- [ ] Verify secret scanning is enabled (should be automatic)
- [ ] Update `CODEOWNERS` to reflect the actual owning team
- [ ] Update Helm values, CI workflows, and Doppler configs to reference the new repo path
- [ ] Update any internal documentation, Backstage entries, or bookmarks that referenced the old repo
- [ ] Archive or delete the personal-account prototype to avoid confusion
- [ ] Notify your team that the canonical repo has moved

---

## FAQ

**Can I keep a fork in my personal account for experimentation?**
Yes, for development and testing. But production deployments, CI pipelines, and team access should always point to the org repo.

**What if my team does not have a CW GitHub org yet?**
Ask your manager or the platform team. Most teams have access to the main `coreweave` org or a team-specific org.

**What about open-source projects?**
Open-source repos have a separate governance process. Talk to the legal and security teams before making any CW-related code public.

**Can I use GitHub Actions in the org repo?**
Yes. The org allows GitHub Actions with an approved list of actions. If you need an action that is not on the allowed list, request it through IT.
