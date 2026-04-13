# CW Integration Guide

How to use this security template alongside CoreWeave's official project scaffolding.

---

## Context

CoreWeave provides official repo scaffolding through the `cw` CLI:

- **`cw repo create`** — Creates a new GitHub repo in the CW org with CODEOWNERS, branch protection, Backstage catalog entry, and default workflows.
- **`cw scaffold generate`** — Generates boilerplate for Go services, Python apps, Helm charts, and other common patterns.

This template (`cw-secure-template`) does not replace the official scaffolding. It **layers security opinions on top of it** — CLAUDE.md guardrails, pre-commit hooks, CI security gates, and operational docs that the official scaffold does not provide.

---

## Path A: Starting a New Project

If you are creating a brand-new service or tool, use the official tooling first, then add the security layers.

```bash
# 1. Create the repo through CW tooling
cw repo create --name my-service --org coreweave --private

# 2. Clone and enter it
git clone git@github.com:coreweave/my-service.git
cd my-service

# 3. Generate any scaffolding you need
cw scaffold generate --type go-service

# 4. Copy the security layers from this template
cp /path/to/cw-secure-template/CLAUDE.md .
cp /path/to/cw-secure-template/.pre-commit-config.yaml .
cp -r /path/to/cw-secure-template/scripts/ ./scripts/
cp /path/to/cw-secure-template/.github/workflows/ci.yml .github/workflows/ci.yml
cp -r /path/to/cw-secure-template/docs/ ./docs/

# 5. Run setup to install hooks and verify tooling
bash scripts/doctor.sh
```

**Important:** Do not overwrite files that `cw repo create` already generated. Merge them instead (see "What NOT to Replace" below).

---

## Path B: Adding to an Existing Repo

If you already have a repo and want to adopt the security layers incrementally, start with the minimum viable set and expand from there.

### Minimum viable adoption

These three files give you the highest security value with the least disruption:

| File | What it does |
|------|-------------|
| `CLAUDE.md` | Constrains AI-generated code to follow CW security standards |
| `.pre-commit-config.yaml` | Blocks secrets, linting failures, and insecure patterns before they reach git |
| `.github/workflows/ci.yml` | Runs security scans, coverage gates, and compliance checks on every PR |

```bash
# Copy the essentials
cp /path/to/cw-secure-template/CLAUDE.md .
cp /path/to/cw-secure-template/.pre-commit-config.yaml .
cp /path/to/cw-secure-template/.github/workflows/ci.yml .github/workflows/

# Install pre-commit hooks
pre-commit install
pre-commit install --hook-type pre-push
```

### Full adoption

Add these when you are ready for deeper coverage:

| File/Directory | What it does |
|----------------|-------------|
| `scripts/doctor.sh` | Verifies local dev environment is correctly configured |
| `scripts/security-fix.sh` | Auto-fixes common security issues Claude flags |
| `scripts/git-hooks/` | Custom pre-commit and pre-push hooks beyond what pre-commit provides |
| `deploy/helm/` | Hardened Helm values with pod security context, TLS, and Doppler integration |
| `docs/` | Operational guides (Okta tickets, Doppler onboarding, approved images, governance) |
| `security-dashboard.html` | Visual security posture overview for the repo |

---

## What NOT to Replace

The `cw repo create` command generates files that are managed by the platform team. Do not overwrite them with this template's versions. Instead, merge the relevant sections.

### CODEOWNERS

The official scaffold generates a `CODEOWNERS` file tied to your team. Keep it. If you want to add security-review requirements, append lines rather than replacing the file:

```
# Existing CODEOWNERS (from cw repo create) — do not remove
*                       @coreweave/my-team

# Security-sensitive files require additional review
CLAUDE.md               @coreweave/my-team @coreweave/appsec
.pre-commit-config.yaml @coreweave/my-team @coreweave/appsec
.github/workflows/      @coreweave/my-team @coreweave/appsec
```

### Backstage catalog-info.yaml

If the scaffold generated a `catalog-info.yaml` for Backstage, keep it as-is. This template does not generate or modify Backstage metadata.

### GitHub workflow defaults

The official scaffold may include workflows for build, test, or deploy. Do not replace them with this template's `ci.yml`. Instead:

1. Keep the existing workflows intact.
2. Add `ci.yml` as a separate workflow file (it is named `ci.yml` specifically to avoid conflicts with common names like `build.yml` or `test.yml`).
3. If there are duplicate steps (e.g., both run `go test`), remove the duplicate from whichever file you consider secondary.

### Branch protection rules

`cw repo create` configures branch protection at the org level. This template includes a `branch-protection-setup.yml` workflow for repos outside the org. If your repo is in the official org, you do not need that workflow — the org-level rules already apply.

---

## Migration Checklist

Use this when adopting the template into an existing repo.

### Phase 1: Foundation (do first)

- [ ] Copy `CLAUDE.md` to repo root
- [ ] Copy `.pre-commit-config.yaml` to repo root
- [ ] Run `pre-commit install && pre-commit install --hook-type pre-push`
- [ ] Run `pre-commit run --all-files` and fix any failures
- [ ] Copy `.github/workflows/ci.yml` (do not overwrite existing workflows)
- [ ] Verify CI passes on a test branch before merging to main

### Phase 2: Dev tooling

- [ ] Copy `scripts/doctor.sh` and run it to verify local environment
- [ ] Copy `scripts/security-fix.sh` for automated remediation
- [ ] Copy `scripts/git-hooks/` if you want the extended hook suite
- [ ] Add `make fix` and `make check` targets to your Makefile (see template Makefile for reference)

### Phase 3: Deployment hardening

- [ ] Review `deploy/helm/values.yaml` and merge relevant settings into your Helm chart
- [ ] Verify pod security context: `runAsNonRoot`, `readOnlyRootFilesystem`, `drop ALL capabilities`
- [ ] Verify Doppler integration: project name, config name, ESO secret references
- [ ] Verify container images use approved Chainguard bases (see `docs/approved-images.md`)

### Phase 4: Documentation and governance

- [ ] Copy `docs/` directory for operational guides
- [ ] File Okta OIDC ticket if your app needs auth (see `docs/okta-ticket-template.md`)
- [ ] Create Doppler project if your app has secrets (see `docs/doppler-onboarding.md`)
- [ ] Confirm repo lives in an approved CW GitHub org (see `docs/repo-governance.md`)
- [ ] Update `security-dashboard.html` with your app's actual values

---

## Staying in Sync

This template will evolve as CW security standards change. To pull updates:

```bash
# Add the template as a remote
git remote add secure-template https://github.com/rpatino-cw/cw-secure-template.git

# Fetch and diff against your branch
git fetch secure-template main
git diff HEAD...secure-template/main -- CLAUDE.md .pre-commit-config.yaml .github/workflows/ci.yml

# Cherry-pick or manually merge what you need
```

Do not blindly merge updates. Review diffs and merge selectively — your app-specific customizations take priority over template defaults.
