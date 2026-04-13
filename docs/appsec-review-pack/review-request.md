# AppSec Review Request

> Copy this into `#application-security` when requesting a review.
> Fill in every field. Replace placeholder text -- do not leave `TODO` items.

---

**Service name:** `<your-service-name>`

**Team / owner:** `<team-name>` / `<@slack-handle or email>`

**Summary:**
<!-- 2-3 sentences: what the service does, who uses it, why it exists -->
TODO: Describe what this service does and its business purpose.

**Timeline:**
<!-- When do you need the review completed by? Give at least 2 weeks lead time. -->
- Requested review by: `YYYY-MM-DD`
- Target deploy date: `YYYY-MM-DD`

**Architecture:**
<!-- Link to your filled-in architecture doc -->
- [architecture.md](architecture.md)

**Threat model:**
<!-- Link to your filled-in threat model -->
- [threat-model.md](threat-model.md)

**Data classification:**
<!-- Link to your filled-in data classification doc -->
- [data-classification.md](data-classification.md)

**Repo:** `https://github.com/coreweave/<repo-name>`

**NPI checklist:** `<link if applicable, or "N/A">`

---

## Security testing status

| Check | Enabled? | Notes |
|-------|----------|-------|
| SAST (CodeQL / GHAS) | Y / N | |
| Secret scanning (Gitleaks) | Y / N | |
| Dependency scanning (Dependabot / Snyk) | Y / N | |
| Container image scanning | Y / N | |
| Branch protection (PR reviews required) | Y / N | |
| Pre-commit hooks (Gitleaks + linters) | Y / N | |

---

## Known risks or concerns

<!-- Be upfront about anything AppSec should pay attention to. Examples: -->
<!-- - "We accept user-uploaded files and store them in S3" -->
<!-- - "Service has network access to the internal Postgres cluster" -->
<!-- - "We're using a vendored fork of library X because upstream lacks feature Y" -->
<!-- - "No rate limiting on the webhook endpoint yet -- tracking in JIRA-1234" -->

1. TODO
2. TODO

---

## Deployment details

| Field | Value |
|-------|-------|
| Cluster | `core-internal` / `core-services` / other |
| Namespace | `<namespace>` |
| Ingress | Traefik internal / public (requires AppSec approval) |
| Access control | BlastShield + Okta OIDC / other |
| Secrets management | Doppler (project: `<project>`, configs: dev/stg/prod) |
| Container base image | `cgr.dev/coreweave/<image>:<tag>` (Chainguard) |
| Deployment method | Helm + Argo / other |

---

*Prepared using [cw-secure-template](https://github.com/coreweave/cw-secure-template) AppSec Review Pack.*
