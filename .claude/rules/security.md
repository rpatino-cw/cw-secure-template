# Glob: **/*.{go,py}

## Security Rules for All Source Code

These rules apply to every Go and Python file in the project.

### Secrets
- Never hardcode API keys, tokens, passwords, or connection strings
- Always use `os.Getenv()` (Go) or `os.environ[]` (Python)
- If a user pastes a secret, redirect to `make add-secret`

### Authentication
- Every endpoint except /healthz requires authentication
- Use `middleware.RequireAuth()` (Go) or `Depends(get_current_user)` (Python)
- Never implement custom username/password auth

### Input Validation
- All user input validated server-side with strict schemas
- Go: struct tags + validator. Python: Pydantic with `ConfigDict(strict=True)`
- Never use `SELECT *` — specify columns explicitly

### Database Queries
- Always use parameterized queries
- Never concatenate user input into SQL strings
- Use `$1` placeholders (Go/pgx) or `%s` placeholders (Python)

### Error Handling
- Log full error details server-side (with request_id)
- Return generic "Internal server error" to users
- Never expose stack traces, file paths, or database errors

### Dangerous Functions — NEVER USE
- Go: `fmt.Sprintf` for SQL, `os/exec` with user input, `template.HTML()` on user input
- Python: `eval()`, `exec()`, `pickle.loads()`, `os.system()`, `yaml.load()`, `shell=True`
