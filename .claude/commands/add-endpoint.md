# Add a new API endpoint with all security layers.
# Usage: /project:add-endpoint [description of what the endpoint does]

Add a new API endpoint following the security template patterns. Every endpoint MUST include:

## Required for every endpoint

1. **Authentication** — Use `Depends(get_current_user)` (Python) or `middleware.RequireAuth()` (Go)
2. **Input validation** — Use Pydantic `BaseModel` with `ConfigDict(strict=True)` (Python) or struct tags (Go)
3. **Parameterized queries** — If touching a database, never concatenate strings into SQL
4. **Structured logging** — Log the action with `request_id` and `user_id`, never log request bodies or tokens
5. **Error handling** — Return generic errors to the user, log full details server-side
6. **Tests** — Write at least 3 tests: happy path, auth required (401 without token), invalid input (422)
7. **SECURITY LESSON comment** — Explain what this endpoint does and why auth/validation matter here

## Steps

1. Read `$ARGUMENTS` to understand what the endpoint should do
2. Add the route to `main.go` or `src/main.py` (check which language exists)
3. Add the Pydantic model or Go struct for input validation
4. Add the handler with auth + validation + logging
5. Add tests
6. Run `make test` to verify tests pass
