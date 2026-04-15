# Getting Started

From zero to a running, secured app in 6 steps.

---

## Step 1: Get the framework

Open **Terminal** (search "Terminal" in Spotlight on Mac).

```bash
git clone https://github.com/rpatino-cw/cw-secure-template my-app
cd my-app
bash setup.sh
```

Setup does everything: installs git hooks, configures pre-commit, and asks you one question.

---

## Step 2: Pick your stack

Setup asks: **Go or Python?** Pick one. The framework locks to your choice so Claude never mixes languages.

```
Pick your stack:
  1) Python (recommended)
  2) Go

Enter 1 or 2:
```

Not sure? **Pick Python.** It has more blueprints and is easier to extend.

---

## Step 3: Pick a blueprint

Blueprints are starter kits for common app types. Each one comes with the right file structure, dependencies, and rules pre-configured.

```bash
make new BLUEPRINT=api-service
```

**Available blueprints:**

| Blueprint | What you get |
|:----------|:-------------|
| `api-service` | REST API with CRUD, auth, rate limiting |
| `chat-assistant` | Claude-powered chat with streaming and token budgets |
| `batch-processor` | Background job queue with retry and dead letter queue |
| `internal-dashboard` | Authenticated dashboard with data tables and charts |
| `admin-tool` | CRUD admin panel with permissions and audit trail |
| `approval-workflow` | Multi-step approvals with notifications and status tracking |

Not sure which one? Start with `api-service` — it's the most general.

---

## Step 4: Start your app

```bash
make start
```

Open **http://localhost:8080/healthz** in your browser. You should see `{"status":"ok"}`.

Press `Ctrl+C` to stop.

---

## Step 4.5: Got an API key?

Don't paste it in code. Don't paste it to Claude. Run this instead:

```bash
make add-secret
```

It asks for the variable name and value (hidden input — nobody can see what you type). The key goes straight to `.env` — never in code or git.

Got a config file (.json, .pem)? Run `make add-config` — same idea, stores it safely.

---

## Step 5: Build with Claude

Open Claude Code in the project folder. Ask it to build something.

```
> Add a /api/users endpoint that lists all users with pagination
```

Claude adds auth, validation, and tests automatically. You don't ask for it — it just happens. If it tries to skip a security step, the guard blocks it.

---

## Step 6: Save and push

```bash
git add -A && git commit -m "Add users endpoint"
```

The pre-commit hook runs automatically — it checks for secrets, dangerous functions, and architecture violations. If something's wrong, you see a plain English message telling you what to fix.

```bash
git push
```

The pre-push hook runs tests. If they pass, your code goes to GitHub. Then CI runs everything else.

---

## The 4 commands

```
make start         Run your app
make check         All checks before pushing
make doctor        What's wrong? Plain English fixes.
make help          Everything else
```

---

## Set your enforcement level

Different projects need different friction. Set a profile:

```bash
make profile LEVEL=hackathon    # minimal friction — demos and prototypes
make profile LEVEL=balanced     # moderate — internal tools
make profile LEVEL=strict       # full enforcement (default)
make profile LEVEL=production   # maximum — compliance-required apps
```

---

## Something went wrong?

| What happened | What to do |
|:--|:--|
| Commit blocked | Read the message. It tells you what's wrong. Or run `make fix`. |
| Push blocked | Run `make test`. Fix failures. Push again. |
| App won't start | Run `make doctor`. It checks everything. |
| Claude did something weird | The guard caught it. Read the message and follow instructions. |
| Confused | Run `make help`. Or ask Claude "what should I do next?" |
| Want to learn | Run `make learn` (15-question security quiz) or `make viz` (visual guide). |
