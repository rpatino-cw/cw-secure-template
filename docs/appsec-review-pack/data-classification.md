# Data Classification

## Data Inventory

| Data Type | Classification | Storage Location | Encrypted at Rest? | Retention Period | Who Has Access |
|-----------|---------------|------------------|---------------------|-----------------|----------------|
| User identity (name, email, groups from Okta) | Internal | Application memory (session) | N/A (not persisted) | Session duration | Authenticated users |
| Application configuration | Internal | Doppler | Yes (Doppler-managed) | Permanent | Ops team via Doppler RBAC |
| Application logs | Internal | Stdout -> log aggregator | Depends on aggregator | 90 days | Ops team |
| API keys and secrets | Restricted | Doppler | Yes (Doppler-managed) | Until rotated | Service account (ESO) |
| Health check responses | Public | None (ephemeral) | N/A | None | Anyone (unauthenticated `/healthz`) |
| TODO: Application-specific data | TODO | TODO | TODO | TODO | TODO |
| TODO: User-generated content | TODO | TODO | TODO | TODO | TODO |

> **Classification levels:**
> - **Public** -- No impact if disclosed. Example: health check status.
> - **Internal** -- For CoreWeave employees only. Default for most internal tool data.
> - **Confidential** -- Business-sensitive. Requires access controls and encryption.
> - **Restricted** -- Highest sensitivity. Secrets, credentials, PII subject to regulation.

> **Instructions:** Add rows for every type of data your application handles. Be thorough -- AppSec will ask about anything missing.

---

## PII Assessment

**Does the application handle Personally Identifiable Information (PII)?**

- [ ] No -- the application does not process, store, or transmit PII
- [ ] Yes -- limited to identity attributes from Okta (name, email)
- [ ] Yes -- the application handles additional PII (describe below)

**If yes, describe the PII:**

| PII Field | Source | Purpose | Stored? | Where? | Retention |
|-----------|--------|---------|---------|--------|-----------|
| Display name | Okta ID token | UI display, audit logs | Session only / Yes | TODO | TODO |
| Email address | Okta ID token | User identification, notifications | Session only / Yes | TODO | TODO |
| TODO | TODO | TODO | TODO | TODO | TODO |

**PII handling controls:**
- PII is never logged (enforced by structured logging rules)
- PII is never included in error responses
- PII is transmitted only over TLS
- PII access requires authentication via Okta OIDC

---

## Compliance Scope

Check all that apply to this service:

- [ ] **SOC 2** -- Service handles data subject to SOC 2 audit controls
- [ ] **ISO 27001** -- Service is in scope for ISO 27001 certification
- [ ] **ISO 27701** -- Service processes personal data subject to privacy controls
- [ ] **PCI DSS** -- Service handles payment card data
- [ ] **HIPAA** -- Service handles protected health information
- [ ] **None** -- No specific compliance framework applies

**Notes:**
<!-- If a compliance framework applies, note any specific controls or requirements -->
TODO

---

## Data Retention Policy

| Data Type | Retention Period | Deletion Method | Justification |
|-----------|-----------------|-----------------|---------------|
| Application logs | 90 days | Automatic (log aggregator TTL) | Operational debugging; aligns with CW log retention standard |
| Session data | Session duration | Automatic (session expiry) | No need to persist beyond session |
| Secrets | Until rotated | Doppler rotation | Least-privilege, regular rotation |
| TODO: Application data | TODO | TODO | TODO |

---

## Data Deletion Process

**How is data deleted when retention expires or a deletion request is received?**

<!-- Describe the process for each data type. Include: -->
<!-- - Who can request deletion? -->
<!-- - How is deletion verified? -->
<!-- - Is deletion logged? -->
<!-- - Are backups also purged? -->

| Data Type | Deletion Trigger | Process | Verified By |
|-----------|-----------------|---------|-------------|
| Application logs | TTL expiry (90 days) | Automatic purge by log aggregator | Ops team spot-checks |
| Session data | Session expiry / logout | Automatic cleanup | Application health checks |
| Secrets | Rotation event | Old secret removed from Doppler | Doppler audit log |
| TODO: Application data | TODO | TODO | TODO |

---

## Data Flow Summary

<!-- Brief description of where data enters, how it moves, and where it exits the system -->

1. **Ingress:** Data enters via HTTPS through Traefik internal ingress
2. **Authentication:** BlastShield validates Okta OIDC tokens at the edge
3. **Processing:** Application processes requests in-memory; validated inputs only
4. **Storage:** Persistent data stored in TODO (database/cache); secrets from Doppler via ESO
5. **Egress:** Responses returned over HTTPS; external API calls authenticated and TLS-enforced
6. **Logging:** Structured JSON logs shipped to centralized aggregator; no secrets or PII logged

---

*Prepared using [cw-secure-template](https://github.com/coreweave/cw-secure-template) AppSec Review Pack.*
