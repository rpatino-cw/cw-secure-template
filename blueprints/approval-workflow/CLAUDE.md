# Blueprint: Approval Workflow

This project uses the **Approval Workflow** blueprint — a multi-step request system with approvals and notifications.

## Architecture

```
routes/      → Request submission, approval/rejection endpoints, status queries
services/    → Workflow state machine, notification dispatch, approval logic
models/      → Request model (status, steps, timestamps), Approver model
repositories/→ Request queries (by status, by approver, by requester)
middleware/  → Auth (Okta OIDC), role-based access (requester vs approver)
```

## State Machine

```
  DRAFT → SUBMITTED → PENDING_APPROVAL → APPROVED → COMPLETED
                           │
                           └──→ REJECTED → (requester can resubmit)
```

## Rules

All rules from `.claude/rules/` apply. Key ones for this blueprint:
- Every state transition logs to an audit trail (who, when, from-state, to-state, comment)
- Approvers cannot approve their own requests (self-approval blocked in service layer)
- Status transitions are enforced by the state machine — no skipping steps
- Notifications are fire-and-forget (queued, not blocking the response)
- 80% test coverage minimum
- Test every valid and invalid state transition
