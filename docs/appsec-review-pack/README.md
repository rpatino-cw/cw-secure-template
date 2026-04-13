# AppSec Review Pack

Ready-to-fill templates for your Application Security review at CoreWeave.

## What is this?

This pack contains everything you need to prepare for an AppSec review before deploying a new service or making significant changes to an existing one. Instead of scrambling to document your architecture and security posture after posting in `#application-security`, fill these templates out first and include them in your review request.

## When to use it

- Before deploying a new service to production
- Before making significant architectural changes to an existing service
- When adding new external dependencies or data flows
- When changing authentication, authorization, or data handling patterns
- When onboarding a service to a new cluster or namespace

## What to include

Your review request should include:

| Document | Template | Purpose |
|----------|----------|---------|
| Review request | [review-request.md](review-request.md) | Copy-paste post for `#application-security` |
| Architecture | [architecture.md](architecture.md) | System overview, components, data flow |
| Threat model | [threat-model.md](threat-model.md) | STRIDE analysis, trust boundaries, mitigations |
| Data classification | [data-classification.md](data-classification.md) | Data inventory, PII assessment, retention |

## How to request a review

1. Copy the templates into your repo under `docs/appsec-review/` (or similar)
2. Fill in every section -- leave nothing as `TODO` unless genuinely unknown
3. Post the completed [review-request.md](review-request.md) in `#application-security`
4. Link to your filled-in architecture, threat model, and data classification docs
5. AppSec will schedule a review based on your timeline and risk profile

For the full process, see CoreWeave's internal guide:
**"How to Request a Security or Design Review"** in the Security team's Confluence space, or ask in `#application-security`.

## Tips for a smooth review

- **Do not wait until the last minute.** Post your request at least 2 weeks before your target deploy date.
- **Be specific about risks.** AppSec reviewers would rather see "we know this is a risk and here's why we accepted it" than discover undocumented gaps.
- **Pre-enable scanning.** CodeQL/GHAS, secret scanning, and dependency scanning should already be enabled on your repo before requesting a review. If they are not, that will be the first thing AppSec flags.
- **Include a working architecture diagram.** Mermaid, ASCII, or an image -- anything that shows the request flow, auth boundaries, and data stores.
