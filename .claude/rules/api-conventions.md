# Glob: **/main.{go,py}

## API Conventions

### Endpoints
- RESTful naming: `/api/resource` (plural), not `/api/getResource`
- Always `GET` for reads, `POST` for creates, `PUT` for updates, `DELETE` for deletes
- Health check at `/healthz` (unauthenticated, returns `{"status": "ok"}`)
- Auth info at `/api/me` (authenticated, returns user claims)

### Response Format
- Success: `{"field": "value"}` — flat JSON, no wrapper
- Error: `{"error": "message"}` — generic message, no internals
- List: `[{"id": 1}, {"id": 2}]` — array at top level
- Never return raw strings or HTML from API endpoints

### Status Codes
- 200: Success
- 201: Created
- 400: Bad request (malformed input)
- 401: Unauthorized (no token or invalid token)
- 403: Forbidden (valid token, wrong permissions)
- 404: Not found
- 413: Payload too large
- 422: Validation error (Pydantic/struct validation failed)
- 429: Rate limited
- 500: Internal error (never expose details)

### Headers
Every response must include:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Content-Security-Policy: default-src 'self'`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- `X-Request-ID: [uuid]`
