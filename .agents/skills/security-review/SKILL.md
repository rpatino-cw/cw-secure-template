---
name: security-review
description: Automatically reviews code changes for security issues. Triggers on any Go or Python file edit. Checks for hardcoded secrets, missing auth, dangerous functions, SQL injection patterns, and logging violations.
user-invocable: true
---

# Security Review Skill

Automatically reviews code for security vulnerabilities when Go or Python files are changed.

## Trigger

This skill activates when any `.go` or `.py` file is edited or created.

## What It Checks

1. **Hardcoded secrets** — scan for string literals that look like API keys, tokens, passwords
   - Pattern: strings matching `sk-`, `ghp_`, `Bearer `, `password=`, `secret=`, API key formats
2. **Missing authentication** — flag new HTTP handlers/routes without auth middleware
3. **Dangerous functions** — flag `eval()`, `exec()`, `pickle.loads()`, `os.system()`, `yaml.load()`, `shell=True`, `InsecureSkipVerify`
4. **SQL injection** — flag string concatenation or f-strings in SQL queries
5. **Logging violations** — flag logging of `Authorization` headers, passwords, tokens, or request bodies
6. **Input validation** — flag POST/PUT handlers accepting raw dicts/maps instead of validated models
7. **Error exposure** — flag `err.Error()` or `str(e)` returned directly to clients

## Output

For each issue found:
- What: one-line description
- Where: file:line
- Fix: exact code change

If no issues: "Security review passed — no issues found."

## Instructions

1. Read the changed files
2. Run each check against the code
3. Report findings in the format above
4. If the user asks to bypass a finding, explain why it matters and suggest the secure alternative
