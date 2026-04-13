# Run a security review of the codebase.
# Usage: /project:security-review

Perform a thorough security review of the current codebase.

## Review checklist

1. **Secrets scan** — Run `gitleaks detect --source . --no-banner` and report findings
2. **Dropped files scan** — Run `bash scripts/scan-drops.sh` and report findings
3. **Auth coverage** — Check every route in main.go/main.py. Flag any endpoint missing `RequireAuth` or `Depends(get_current_user)` (except /healthz)
4. **Input validation** — Check every POST/PUT/PATCH handler. Flag any that accept raw dicts/maps instead of validated models
5. **SQL safety** — Grep for string concatenation in SQL queries (`fmt.Sprintf.*SELECT`, `f"SELECT`, `f"INSERT`)
6. **Dangerous functions** — Grep for: eval, exec, pickle.loads, os.system, yaml.load, shell=True, InsecureSkipVerify
7. **Logging safety** — Grep for logged Authorization headers, passwords, tokens, or API keys
8. **Dependency health** — Run `govulncheck` or `pip-audit` and report vulnerable packages
9. **CORS config** — Check if CORS_ORIGINS is set to "*" in .env or code
10. **Security headers** — Verify X-Content-Type-Options, X-Frame-Options, CSP, HSTS are set

## Output format

For each finding:
- **What:** one sentence describing the issue
- **Where:** file:line
- **Severity:** Critical / High / Medium / Low
- **Fix:** exact code change or command to run

End with a summary: X issues found (Y critical, Z high).
