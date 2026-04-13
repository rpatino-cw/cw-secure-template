# Threat Model

## Scope

**What system or component is being modeled?**
<!-- Be specific: "the user-facing API and its database" not "the whole platform" -->
TODO

**Out of scope:**
<!-- Explicitly list what is NOT covered by this threat model -->
TODO

---

## Trust Boundaries

<!-- A trust boundary is where the level of trust changes -- where trusted meets untrusted. -->
<!-- Draw or list these clearly. Every boundary is a potential attack surface. -->

```
┌─────────────────────────────────────────────────────────┐
│  UNTRUSTED                                              │
│  - User browser / client                                │
│  - External API responses                               │
│  - Webhook payloads                                     │
├─────────────────────────────────────────────────────────┤
│  BOUNDARY: Traefik Ingress + BlastShield + Okta OIDC    │
├─────────────────────────────────────────────────────────┤
│  TRUSTED (authenticated)                                │
│  - Application service                                  │
│  - Internal service-to-service calls (mTLS)             │
│  - Database (namespace-scoped network policy)           │
│  - Doppler secrets (ESO-managed)                        │
└─────────────────────────────────────────────────────────┘
```

> Update this diagram to match your actual trust boundaries.

---

## Assets

What are we protecting?

| Asset | Sensitivity | Why it matters |
|-------|-------------|----------------|
| User identity (Okta tokens, group claims) | Internal | Impersonation, privilege escalation |
| API keys and secrets (Doppler) | Restricted | Service compromise, lateral movement |
| Application data in database | TODO | TODO |
| Application logs | Internal | May contain metadata useful for reconnaissance |
| Internal configuration | Internal | Reveals architecture, endpoints, dependencies |
| TODO | TODO | TODO |

---

## STRIDE Analysis

| Category | Threat Description | Likelihood | Impact | Mitigation | Status |
|----------|--------------------|------------|--------|------------|--------|
| **Spoofing** | Attacker forges or replays an auth token to impersonate a user | M | H | Okta OIDC with JWKS validation; tokens verified on every request; short-lived access tokens; BlastShield enforces auth at ingress | Mitigated |
| **Spoofing** | Attacker uses stolen session cookie | M | H | httpOnly + Secure + SameSite cookies; no localStorage tokens; session expiry | Mitigated |
| **Spoofing** | Service-to-service call from unauthorized internal service | L | H | Client Credentials flow with scoped service accounts; namespace-level NetworkPolicies | Mitigated |
| **Tampering** | SQL injection via user input | M | H | Parameterized queries for all database operations; no string concatenation in SQL; input validated with strict schemas | Mitigated |
| **Tampering** | Request body tampering (extra fields, type coercion) | M | M | Strict input validation; reject unexpected fields; use Go struct tags + validator or Python Pydantic models | Mitigated |
| **Tampering** | Dependency supply chain attack (malicious package update) | L | H | Pinned dependency versions; Dependabot/Snyk scanning; Chainguard base images; signed artifacts | Mitigated |
| **Repudiation** | User denies performing a destructive action | M | M | Structured audit logging of all auth events and state-changing operations; logs include user_id, request_id, timestamp | Mitigated |
| **Repudiation** | Attacker modifies or deletes logs to cover tracks | L | H | Logs shipped to centralized aggregator (stdout -> collector); application has no write access to log storage | Mitigated |
| **Info Disclosure** | Secret committed to git (API key, token, password) | M | H | Gitleaks pre-commit hook; CI secret scanning (GHAS); all secrets in Doppler, never in code; `.gitignore` blocks `.env` | Mitigated |
| **Info Disclosure** | Verbose error messages expose internal paths or stack traces | M | M | Generic error responses to clients; detailed errors logged internally only; structured logging strips sensitive fields | Mitigated |
| **Info Disclosure** | Secrets or PII leaked in application logs | M | H | Logging rules: never log Authorization headers, tokens, passwords, PII; code review enforces logging policy | Mitigated |
| **Info Disclosure** | Unauthorized access to database from adjacent namespace | L | H | Namespace-scoped NetworkPolicies; database credentials scoped per service; connection pool limits | Mitigated |
| **Denial of Service** | API flooding / resource exhaustion | M | M | Rate limiting on all endpoints (default 100 req/min/IP, configurable); request body size limits (default 1MB); server timeouts (read: 15s, write: 15s, idle: 60s) | Mitigated |
| **Denial of Service** | Oversized request body causes OOM | L | M | MaxBytesReader / Content-Length middleware; 413 returned for oversized payloads | Mitigated |
| **Denial of Service** | Slowloris / connection exhaustion | L | M | ReadTimeout, WriteTimeout, IdleTimeout configured on server; graceful shutdown on SIGTERM | Mitigated |
| **Elevation of Privilege** | User accesses admin-only endpoint without proper role | M | H | Group-based RBAC via Okta group claims; authorization middleware on every endpoint; principle of least privilege | Mitigated |
| **Elevation of Privilege** | Container escape or privilege escalation in pod | L | H | Non-root container; Chainguard minimal base image; no privileged capabilities; PodSecurityPolicy/Standards enforced | Mitigated |
| **Elevation of Privilege** | SSRF allows internal network scanning | L | H | Outbound URL allowlisting; no user-controlled fetch targets; validate/sanitize all URLs | Mitigated |
| TODO | TODO: Add threats specific to your application | TODO | TODO | TODO | Open |

> **Instructions:**
> - Keep the pre-filled rows that apply to your service. Remove any that do not.
> - Add rows for threats specific to your application (file uploads, webhooks, batch processing, etc.).
> - Mark **Status** as: `Mitigated`, `Accepted`, `Open`, or `In Progress`.
> - For `Accepted` risks, document the justification in the Residual Risks section below.

---

## Residual Risks

Threats that are NOT fully mitigated. Document what remains and why it is accepted.

| Threat | Current mitigation | Residual risk | Justification |
|--------|--------------------|---------------|---------------|
| TODO | TODO | TODO | TODO |

> If all threats are fully mitigated, state: "No residual risks identified at time of review."

---

## Review Date

- **Initial threat model created:** `YYYY-MM-DD`
- **Last reviewed:** `YYYY-MM-DD`
- **Next scheduled review:** `YYYY-MM-DD` (recommend quarterly or after significant changes)
- **Reviewed by:** `<names or team>`

---

*Prepared using [cw-secure-template](https://github.com/coreweave/cw-secure-template) AppSec Review Pack.*
