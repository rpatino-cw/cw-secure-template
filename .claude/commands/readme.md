# Generate a README for this project

Analyze this project and generate a clean, concise README.md. Under 150 lines.

## Steps

1. Read the project structure: `find . -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' -not -path '*/rooms/*' -type f | head -100`
2. Read CLAUDE.md to understand the project's purpose and stack
3. Read any existing README.md
4. Check what language/framework is being used (Go, Python, or both)

## README Template

Generate a README with this structure:

```markdown
<h1 align="center">[Project Name]</h1>
<p align="center"><strong>[One-line description]</strong></p>

<p align="center">
  [Badges: language, framework, security status]
</p>

---

[One sentence: what this is and why it exists]

\`\`\`bash
git clone [repo-url] && cd [name] && bash setup.sh
\`\`\`

\`\`\`
make start         Run your app
make check         Run before pushing
make rooms         Set up multi-agent coordination (optional)
\`\`\`

**Requires:** [dependencies]

---

<details>
<summary>[Feature 1]</summary>
[Brief explanation — 3-5 lines max]
</details>

<details>
<summary>[Feature 2]</summary>
[Brief explanation]
</details>

---

<p align="center"><sub>[Footer]</sub></p>
```

## Rules

- Under 150 lines — the CI gates this
- Lead with the clone command — people want to try it, not read about it
- Use `<details>` for everything after the quick start — don't force people to scroll
- Badges: only language + one key differentiator (security, coverage, etc.)
- No "Table of Contents" — the README is too short to need one
- No "Contributing" section — put that in CONTRIBUTING.md if needed
- No screenshots in the README — link to the landing page instead
- Write for someone who has 30 seconds. If they're still reading after the clone command, they're interested — give them the collapsibles
