## What does this PR do?
<!-- 1-3 sentences -->

## Security Checklist

> Every PR must pass this checklist. If a box doesn't apply, check it and note "N/A."

- [ ] **No hardcoded secrets** — API keys, tokens, passwords are in env vars, not source code
- [ ] **Auth applied** — new endpoints require authentication (Okta OIDC)
- [ ] **Input validated** — user input is validated server-side with strict schemas
- [ ] **Parameterized queries** — no string concatenation in SQL or shell commands
- [ ] **Error handling** — errors logged internally, generic messages returned to users
- [ ] **No dangerous functions** — no `eval`, `exec`, `os.system`, `shell=True`, `pickle.loads`
- [ ] **Dependencies justified** — new packages are necessary, pinned, and from trusted sources
- [ ] **Secrets not logged** — log statements don't expose tokens, passwords, or PII
- [ ] **TLS enforced** — external calls use HTTPS, TLS verification not disabled
- [ ] **Tests added** — new logic has corresponding test coverage

## How to test
<!-- Steps a reviewer can follow to verify this works -->

## Anything else?
<!-- Breaking changes, migration steps, deployment notes -->
