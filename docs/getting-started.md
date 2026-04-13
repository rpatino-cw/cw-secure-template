# Getting Started

---

## Step 1: Get the template

Open **Terminal** (search "Terminal" in Spotlight on Mac).

<p align="center"><img src="visuals/step1-setup.svg" width="100%"></p>

---

## Step 2: Pick your language

Setup asks one question. **Pick 1 for Python** (recommended).

<p align="center"><img src="visuals/step2-pick.svg" width="100%"></p>

---

## Step 3: Start your app

<p align="center"><img src="visuals/step3-start.svg" width="100%"></p>

Open **http://localhost:8080/healthz** in your browser. You should see `{"status":"ok"}`.

Press `Ctrl+C` to stop.

---

## Step 3.5: Got an API key?

Don't paste it in code. Don't paste it to Claude. Run this instead:

<p align="center"><img src="visuals/step4-secret.svg" width="100%"></p>

Got a config file (.json, .pem)? Run `make add-config` — same idea, stores it safely.

---

## Step 4: Build with Claude

Open Claude Code in the project folder. Ask it to build something.

<p align="center"><img src="visuals/step5-build.svg" width="100%"></p>

Claude adds auth, validation, and tests automatically. You don't ask for it — it just happens.

---

## Step 5: Save your changes

<p align="center"><img src="visuals/step6-commit.svg" width="100%"></p>

If something's wrong, you'll see a plain English message telling you exactly what to fix.

---

## Step 6: Push

<p align="center"><img src="visuals/step7-push.svg" width="100%"></p>

Tests run before push. If they pass, your code goes to GitHub. Then CI runs everything else.

---

## The 3 commands

```
make start    Run your app
make check    Before pull requests
make help     Everything else
```

---

## Something went wrong?

| What happened | What to do |
|:--|:--|
| Commit blocked | Read the message. Or run `make fix`. |
| Push blocked | Run `make test`. Fix failures. Push again. |
| App won't start | Run `make doctor`. |
| Confused | Run `make help`. Or ask Claude "what should I do next?" |
| Want to learn | Run `make learn` (security quiz) or `make dashboard` (visual guide). |
