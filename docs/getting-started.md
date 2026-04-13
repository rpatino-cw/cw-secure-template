# Getting Started

A step-by-step guide for your first 10 minutes with the CW Secure Template. No security or programming experience required.

---

## Step 1: Get the template

Open the **Terminal** app on your Mac (search "Terminal" in Spotlight).

Type this and press Enter:

```
git clone https://github.com/rpatino-cw/cw-secure-template my-app
```

Then move into the folder:

```
cd my-app
```

---

## Step 2: Run setup

Type this and press Enter:

```
bash setup.sh
```

You'll see a few questions:
- **Which language?** — Press `1` for Python (recommended) and hit Enter.
- Everything else is automatic.

Setup takes about 2 minutes. When it's done, you'll see a green "Setup complete!" message and the Security Dashboard will open in your browser.

---

## Step 3: Start your app

Type this:

```
make start
```

You'll see something like:

```
INFO:     Uvicorn running on http://0.0.0.0:8080
```

Your app is running. Open a browser and go to **http://localhost:8080/healthz** — you should see `{"status":"ok"}`.

Press `Ctrl+C` to stop the app when you're done.

---

## Step 4: Build something with Claude

Open **Claude Code** (or any AI coding tool) in the `my-app` folder.

Try a prompt like:

> "Add an endpoint that returns a list of my favorite movies"

Claude will:
- Add the endpoint with authentication
- Validate the input
- Set security headers
- Add a test

You don't need to ask for any of that — it happens automatically because of the `CLAUDE.md` file.

---

## Step 5: Save your changes

After Claude makes changes, save them to git:

```
git add -A
git commit -m "Add movies endpoint"
```

When you commit, you'll see the security checks run automatically:
- Secret scanning (looking for passwords in your code)
- Code style checking
- Security issue scanning

If everything passes, your commit goes through.
If something fails, you'll see a plain-English message explaining what's wrong and how to fix it.

---

## Step 6: Push your code

When you're ready to share your code:

```
git push
```

Before pushing, the template automatically runs your tests. If they pass, your code goes to GitHub.

---

## Step 7: Open a pull request

Go to your repo on GitHub and click "New Pull Request." You'll see a security checklist — go through each item.

A teammate reviews your code, the CI pipeline runs all security scanners, and when everything is green, you merge.

---

## The 3 commands you need

| Command | When to use it |
|:--------|:---------------|
| `make start` | Run your app locally |
| `make check` | Before opening a pull request |
| `make help` | When you need anything else |

That's it. Everything else (security scanning, secret detection, auth, rate limiting) is automatic.

---

## Something went wrong?

| Problem | Solution |
|:--------|:---------|
| Commit was blocked | Read the message — it tells you exactly what to fix. Or run `make fix`. |
| Push was blocked | Run `make test` to see which tests failed. Fix them, commit, push again. |
| App won't start | Run `make doctor` to check your setup. |
| I'm confused | Run `make help` for all commands, or ask Claude "what should I do next?" |
| I want to learn more | Run `make learn` for a security quiz, or `make dashboard` for the visual guide. |

---

## What's protecting you

You don't need to understand all of this, but in case you're curious:

1. **CLAUDE.md** tells Claude to write secure code even if you ask it not to
2. **Pre-commit hooks** scan for passwords and code issues before every commit
3. **Pre-push hooks** run tests before your code leaves your machine
4. **CI pipeline** runs security scanners on every pull request
5. **PR review** requires a teammate to check your code
6. **Helm deployment** runs your app in a secure container with encrypted secrets

Each layer catches what the previous one missed. Even if you make a mistake, the pipeline catches it.
