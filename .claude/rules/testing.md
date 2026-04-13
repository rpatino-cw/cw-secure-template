# Glob: **/*_test.{go,py}

## Testing Rules

### Coverage
- Target: 80% minimum (enforced by CI)
- Every new endpoint needs at least 3 tests: happy path, auth required, invalid input

### Test Structure
- Go: table-driven tests with `t.Run()` subtests
- Python: pytest with descriptive function names (`test_create_item_missing_name`)
- Every test has a docstring explaining what it verifies

### Security Tests
- Test that unauthenticated requests return 401
- Test that invalid input returns 422 (not 500)
- Test that error responses don't leak internal details
- Test that security headers are present on all responses
- Test that rate limiting returns 429 with Retry-After

### Environment
- Tests use `DEV_MODE=true` for auth bypass
- Tests set `ALLOWED_HOSTS` to include the test client hostname
- Never use real API keys or secrets in tests — use env vars or mocks
