# Run all security checks before a pull request.
# Usage: /project:check

Run the full security and quality check suite. Do this before every pull request.

## Steps

1. Run `make lint` — check code style
2. Run `make test` — run all tests
3. Run `make scan` — deep security scan (gitleaks, gosec/bandit, dependency audit)
4. Run `bash scripts/scan-drops.sh` — check for accidentally dropped sensitive files
5. Summarize: how many checks passed, what failed, and what to fix

If everything passes, say: "All checks passed. You're ready to open a PR."
If anything fails, explain each failure in plain English and how to fix it.
