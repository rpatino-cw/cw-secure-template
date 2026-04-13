# Security Policy

## Reporting Vulnerabilities

If you discover a security vulnerability in this project, **do not open a public issue.**

Report it through one of these channels:

- **Email:** Post in #application-security on Slack (preferred) or email the AppSec team directly
- **Slack:** [#application-security](https://coreweave.slack.com/archives/application-security)
- **PagerDuty:** For critical/actively-exploited vulnerabilities, use the AppSec on-call rotation

Include in your report:
- Description of the vulnerability
- Steps to reproduce
- Affected versions/components
- Potential impact assessment
- Any suggested fix (optional)

**Response SLA:** You will receive an acknowledgment within 2 business days and a detailed response within 7 business days.

---

## Supported Versions

| Version | Supported          | Notes                       |
|---------|--------------------|-----------------------------|
| 1.x     | Yes                | Current release, active dev |
| 0.9.x   | Security fixes only| Maintenance mode            |
| < 0.9   | No                 | End of life                 |

Only supported versions receive security patches. Upgrade to the latest supported version as soon as possible.

---

## Security Update Process

1. **Discovery** -- Vulnerability identified via report, scan, or audit.
2. **Triage** -- AppSec team assesses severity using CVSS v3.1 scoring.
3. **Fix development** -- Patch developed on a private branch, reviewed by 2+ engineers.
4. **Release** -- Patched version published. Helm chart updated. Affected deployments rolled.
5. **Disclosure** -- After fix is deployed, a security advisory is published with:
   - CVE ID (if applicable)
   - Affected versions
   - Remediation steps
   - Attribution to reporter (with consent)

**Critical vulnerabilities** (CVSS >= 9.0) target a 24-hour patch-to-deploy cycle.
**High vulnerabilities** (CVSS 7.0-8.9) target a 72-hour cycle.

---

## Incident Response Template

Use this template for any security incident. Copy it into a new document and fill in each section.

### 1. Overview

- **Incident title:** [Brief description]
- **Date of document:** YYYY-MM-DD
- **Author:** [Name / team]
- **Status:** [Active | Contained | Resolved | Post-mortem complete]
- **Severity:** [Critical | High | Medium | Low]

**Summary:** One paragraph describing what happened, what was affected, and the current state.

### 2. Identification

- **When discovered:** YYYY-MM-DD HH:MM UTC
- **How discovered:** [Monitoring alert | Security scan | User report | Audit | Penetration test]
- **Who reported:** [Name / system]
- **Severity justification:** [Why this severity level -- data at risk, blast radius, exploitability]
- **Affected systems:** [List services, endpoints, clusters, data stores]
- **Affected users/data:** [Scope of impact -- number of users, type of data, exposure duration]

### 3. Investigation

- **Root cause:** [Technical explanation of the vulnerability or failure]
- **Attack vector:** [How the issue was or could be exploited]
- **Evidence collected:**
  - [ ] Logs (source: ______)
  - [ ] Network captures
  - [ ] Container/pod forensics
  - [ ] Audit trail records
- **Timeline of events:**
  | Time (UTC) | Event |
  |------------|-------|
  | HH:MM      | [First indicator of compromise / failure] |
  | HH:MM      | [Investigation began] |
  | HH:MM      | [Key finding] |

### 4. Containment

Immediate actions taken to stop the bleeding:

- [ ] Affected service isolated / scaled to zero
- [ ] Compromised credentials rotated
- [ ] Network rules tightened (ingress/egress)
- [ ] Affected secrets rotated in Doppler
- [ ] External access revoked (API keys, tokens, certificates)
- [ ] Communication sent to affected teams

**Containment verified by:** [Name] at [time]

### 5. Eradication

Permanent fix to eliminate the vulnerability:

- [ ] Code fix merged (PR: #______)
- [ ] Patched image built and deployed
- [ ] Infrastructure config updated (Helm values, network policies, RBAC)
- [ ] Dependency updated to patched version
- [ ] Security scan confirms fix (tool: ______)
- [ ] Fix deployed to all affected environments

### 6. Recovery and Follow-up

**Recovery actions:**
- [ ] Service restored to normal operation
- [ ] Monitoring confirms healthy state for 24+ hours
- [ ] Affected users notified (if required)
- [ ] Compliance/legal notified (if PII/regulated data involved)

**Lessons learned:**
- What went well:
- What could be improved:
- What was lucky:

**Preventive measures:**
| Action | Owner | Due date | Status |
|--------|-------|----------|--------|
| [Preventive action 1] | [Team/person] | YYYY-MM-DD | [ ] |
| [Preventive action 2] | [Team/person] | YYYY-MM-DD | [ ] |

**Post-mortem meeting:** Scheduled for YYYY-MM-DD. Attendees: [list].

---

## Security Contacts

| Role                  | Contact                            | Action Required |
|-----------------------|------------------------------------|-----------------|
| Application Security  | #application-security (Slack)      | - |
| Security On-Call      | PagerDuty AppSec rotation          | - |
| Team Lead             | *Fill in when adopting template*   | `TODO` |
| Engineering Manager   | *Fill in when adopting template*   | `TODO` |

---

## Additional Resources

- **AppSec review checklist:** See CLAUDE.md in this repository for the full pre-merge security checklist.
- **CW Security Standards:** Refer to internal Confluence for container hardening, secret management, and network policy standards.
- **External Secrets Operator:** All secrets must flow through ESO/Doppler -- never commit secrets to git. See `deploy/helm/templates/externalsecret.yaml`.
