# Blueprint: Admin Tool

This project uses the **Admin Tool** blueprint — a CRUD admin panel with permissions and audit logging.

## Architecture

```
routes/       → Admin CRUD handlers (list, create, update, delete per resource)
services/     → Permission checks, business validation, audit logging
models/       → Resource models + AuditLog model (who changed what, when)
repositories/ → Database queries with pagination, filtering, bulk operations
middleware/   → Auth (Okta OIDC) + RBAC middleware (admin vs viewer roles)
```

## Rules

All rules from `.claude/rules/` apply. Key ones for this blueprint:
- Every admin action logs to the `audit_log` table (user, action, resource, timestamp)
- Bulk operations (delete, update) require admin role — viewer role is read-only
- List endpoints must support pagination (`?page=1&per_page=25`) and filtering
- Delete operations are soft-delete by default (`deleted_at` timestamp, not `DELETE FROM`)
- 80% test coverage minimum
- Test both admin and viewer role paths for every endpoint
