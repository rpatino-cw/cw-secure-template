# Glob: **/*

## Branch Discipline

Never commit directly to main. All work happens on feature branches.

### Rules
- Before any code change, check the current branch with `git branch --show-current`
- If on `main`, create a feature branch first: `make branch NAME=descriptive-name`
- If `AGENT_ROOM` is set, branches auto-prefix with the room name (e.g., `go/add-auth`)
- When work is done, open a PR: `make pr` — this runs all checks and creates the PR
- Never suggest `git push` to main — always `git push -u origin <branch>`

### Branch naming
- Agents: `{room}/description` (e.g., `go/add-login`, `python/fix-validation`)
- Humans: `feature/description` or `fix/description`
- Keep it short, lowercase, hyphenated

### Before committing
1. Run `make check` — tests + lint + security + room-lint must all pass
2. Commit with a clear message: `git commit -m "Add login endpoint with auth"`
3. Push: `git push -u origin <branch>`
4. Open PR: `make pr`

### CI gates on PRs to main
All of these must pass before merge:
- Secret scanning (gitleaks)
- Lint (golangci-lint / ruff)
- Security scan (gosec / bandit)
- Tests with 80% coverage
- Dependency audit
- Hook integrity (CLAUDE.md sections intact, pre-commit not weakened)
- Middleware wiring verified
- CodeQL analysis
