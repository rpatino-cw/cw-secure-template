# Project Memory

> Claude reads this file to understand project context across sessions.
> Update it as the project evolves — it's the AI's long-term memory for this repo.

## Project Overview

- **Name:** [Your App Name]
- **Purpose:** [What does this app do? Who uses it?]
- **Stack:** [Go / Python] (delete the one you're not using)
- **Status:** [Development / Staging / Production]
- **Team:** [Who works on this? Slack channel?]

## Architecture Decisions

<!-- Record important decisions here so Claude understands WHY things are built a certain way -->

| Decision | Why | Date |
|----------|-----|------|
| Using Okta OIDC for auth | CW standard, required by InfoSec | [date] |
| [Your decision] | [Your reason] | [date] |

## Current Sprint / Focus

<!-- What are you working on right now? Claude uses this to prioritize suggestions -->

- [ ] [Current task 1]
- [ ] [Current task 2]

## Known Issues

<!-- Things Claude should know about but aren't in the code -->

- [None yet]

## External Dependencies

<!-- APIs, services, databases this app talks to -->

| Service | Purpose | Auth Method |
|---------|---------|-------------|
| Okta | User authentication | OIDC / JWT |
| [Database] | [Purpose] | [Connection type] |

## Deployment Notes

- **Cluster:** [core-internal / core-services]
- **Namespace:** [your-namespace]
- **Doppler project:** [project-name]
- **Doppler configs:** dev, stg, prod
