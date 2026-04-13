# Security Handbook

A plain-English guide to application security at CoreWeave, written for people who build internal tools but do not have a security background. No prior security knowledge is assumed.

---

## Table of Contents

1. [What is This Template?](#1-what-is-this-template)
2. [The Pipeline](#2-the-pipeline)
3. [OWASP Top 10 for Humans](#3-owasp-top-10-for-humans)
4. [10 Common Mistakes](#4-10-common-mistakes)
5. [Glossary](#5-glossary)
6. [FAQ](#6-faq)

---

## 1. What is This Template?

### Defense in Depth — the Idea

Security is not one lock on one door. It is a series of locked doors, each behind the other, so that an attacker who picks one lock still faces nine more. This concept is called **defense in depth**. The CW Secure Template embeds security checks at every stage of your development workflow — in your editor, in your git hooks, in your CI pipeline, in your pull request review, and in your deployed infrastructure. No single layer is expected to catch everything. Each layer catches what the previous one missed. If a secret slips past your local scan, CI catches it. If CI misses a vulnerability pattern, CodeQL finds it. If CodeQL misses it, the PR reviewer has a checklist. If the reviewer misses it, production infrastructure (TLS, network policies, RBAC) limits the blast radius.

### What It Protects Against

This template protects against the most common ways internal applications get compromised: leaked API keys and passwords committed to git, SQL injection through sloppy string concatenation, cross-site scripting from unsanitized user input, broken authentication from hand-rolled login systems, missing rate limiting that enables brute-force attacks, and accidental exposure of internal services to the public internet. These are not exotic threats. They are the same mistakes that show up in breach reports year after year, and they are almost always preventable with the right defaults. This template makes the secure path the default path.

### Who It Is For

This template is for anyone at CoreWeave who needs to build an internal web application, API, CLI tool, or background service — regardless of whether they are a seasoned backend engineer or a data center technician writing their first HTTP handler. If you are following a tutorial, hacking together a quick dashboard, or prompting Claude to generate code for you, this template ensures that the output meets CoreWeave's security standards (SOC 2, ISO 27001, OWASP Top 10) without requiring you to memorize those standards yourself. The guardrails are baked in. You build your app; the template handles the security plumbing.

---

## 2. The Pipeline

Every line of code passes through six checkpoints before it reaches production. Here is the flow:

```
 You write code
      |
      v
 +-----------+     +-----------+     +-------------+     +------+     +-----------+     +--------+
 |   Code    | --> | CLAUDE.md | --> | Pre-commit  | --> |  CI  | --> | PR Review | --> | Deploy |
 | (editor)  |     | (AI rules)|     | (git hooks) |     |      |     |           |     |        |
 +-----------+     +-----------+     +-------------+     +------+     +-----------+     +--------+
```

### Stage 1: Code (Your Editor)

**What happens:** You write code, or Claude writes it for you.

**What it catches:** If Claude is generating code, the CLAUDE.md file constrains it to produce secure patterns by default — parameterized queries, environment variables for secrets, Okta auth, proper error handling. This means you get secure code even from imperfect prompts.

**What escapes:** Code written by hand without Claude, or code copied from external sources. The CLAUDE.md rules do not apply to human-written code — that is why the next stages exist.

### Stage 2: CLAUDE.md (AI Guardrails)

**What happens:** The CLAUDE.md file in the repository root contains 14 absolute rules that Claude must follow. These rules cannot be overridden by the person prompting. They cover secrets, authentication, input validation, dangerous functions, error handling, TLS, dependencies, rate limiting, request tracking, request size limits, graceful shutdown, CSRF, test coverage, and git hygiene.

**What it catches:** Insecure AI-generated code. If someone prompts "just hardcode the API key for now," Claude refuses and uses an environment variable instead. If someone says "skip auth, I'll add it later," Claude adds auth with a DEV_MODE bypass for local testing.

**What escapes:** Human-written code, code pasted from Stack Overflow, and prompts to non-Claude AI tools that do not read the CLAUDE.md file.

### Stage 3: Pre-commit (Git Hooks)

**What happens:** Every time you run `git commit`, the pre-commit hook runs automatically. It executes:
- **Gitleaks** — scans for API keys, tokens, passwords, and other secrets in your staged files
- **detect-private-key** — catches accidentally committed private keys
- **no-commit-to-branch** — blocks direct commits to `main` or `master`
- **golangci-lint** (Go) — static analysis for code quality and security patterns
- **ruff** (Python) — linting and formatting enforcement
- **bandit** (Python) — security-focused static analysis that flags `eval()`, `exec()`, `pickle.loads()`, and other dangerous patterns
- **General hygiene** — trailing whitespace, valid YAML/JSON, large file blocking

**What it catches:** Secrets about to be committed, direct commits to main, dangerous function calls, linting violations, formatting issues.

**What escapes:** Complex logic bugs, business logic flaws, architectural issues, and vulnerabilities that require understanding the full codebase (not just individual files). Also, someone can run `--no-verify` to skip hooks — but the next stage catches that.

### Stage 4: CI (GitHub Actions)

**What happens:** When you push to a branch or open a PR, the CI pipeline runs six jobs:
1. **Secret Scanning** — Gitleaks runs on the full commit history, not just the diff
2. **Go Checks** — lint, gosec (security scanner), tests with race detection, 80% coverage gate, SBOM generation
3. **Python Checks** — ruff lint, ruff format, bandit security scan, pytest with 80% coverage gate, SBOM generation
4. **Dependency Audit** — govulncheck (Go) and pip-audit (Python) check all dependencies against known vulnerability databases
5. **CodeQL Analysis** — GitHub's deep static analysis engine that finds injection flaws, data flow issues, and logic bugs across the entire codebase
6. **Hook Integrity Check** — verifies that nobody removed pre-commit hooks from the config, nobody deleted security sections from CLAUDE.md, and that `.last-hook-run` is recent (proving you did not skip hooks with `--no-verify`)

**What it catches:** Everything the pre-commit hooks catch (redundancy is intentional), plus: vulnerable dependencies, complex injection patterns that require data-flow analysis, missing test coverage, skipped hooks, tampered security configurations.

**What escapes:** Business logic flaws that look correct to static analysis, authorization bugs where the code runs but grants too much access, and race conditions that tests do not cover.

### Stage 5: PR Review (Human Eyes)

**What happens:** Every PR to main requires reviewer approval. The PR template includes a 10-item security checklist:
- No hardcoded secrets
- Auth applied to new endpoints
- Input validated server-side
- Parameterized queries (no string concatenation)
- Error handling (internal logging, generic external messages)
- No dangerous functions
- Dependencies justified and pinned
- Secrets not logged
- TLS enforced
- Tests added

**What it catches:** Context-dependent issues that automated tools miss — "this endpoint should require admin, not just any user," "this logging statement would expose PII," "this dependency is unmaintained."

**What escapes:** Subtle issues the reviewer does not notice, especially under time pressure. This is why automated checks exist — they never get tired.

### Stage 6: Deploy (Infrastructure)

**What happens:** The app is containerized using Chainguard base images, deployed to CoreWeave's internal Kubernetes cluster via Helm and Argo, placed behind Traefik internal ingress, and gated with BlastShield + Okta OIDC. Secrets come from Doppler via External Secrets Operator — they never exist in git or in the container image.

**What it catches:** Network-level attacks (TLS terminates at ingress), unauthorized access (BlastShield + Okta), secret exposure (Doppler manages rotation), container vulnerabilities (Chainguard minimal images), and runtime misconfigurations (health checks, resource limits, non-root execution).

**What escapes:** Application-level logic bugs that made it through all prior stages. At this point, structured logging and monitoring are your last line of defense — anomalous behavior triggers alerts.

---

## 3. OWASP Top 10 for Humans

The [OWASP Top 10](https://owasp.org/Top10/) is the industry standard list of the most critical web application security risks. This section explains each one in plain English.

---

### A01: Broken Access Control

**Plain English:** Your app lets people do things they should not be allowed to do — view other users' data, access admin pages, delete records they do not own.

**Physical-world analogy:** A hotel where every room key opens every door. You have a key, so you can get into your room — but you can also get into everyone else's room because nobody checked which room you belong to.

**How attackers exploit it:** An attacker logs in as a normal user, then changes the URL from `/users/123/profile` to `/users/456/profile` and sees someone else's data. Or they find an admin endpoint like `/admin/delete-user` that does not check if the requester is actually an admin. These are called Insecure Direct Object Reference (IDOR) attacks.

**What this template does:**
- Every endpoint requires Okta OIDC authentication by default (RequireAuth middleware)
- RBAC is enforced through Okta group claims (RequireGroup middleware)
- The CLAUDE.md rules prevent Claude from generating endpoints without auth
- DEV_MODE bypasses auth only locally and logs loud warnings

**BAD code — Go:**
```go
// BROKEN: Anyone can view any user's profile by changing the ID
func GetProfile(w http.ResponseWriter, r *http.Request) {
    userID := r.URL.Query().Get("id")
    profile, _ := db.GetUser(userID)
    json.NewEncoder(w).Encode(profile)
}
```

**GOOD code — Go:**
```go
// SECURE: User can only access their own profile (from JWT claims)
func GetProfile(w http.ResponseWriter, r *http.Request) {
    claims := middleware.UserFromContext(r.Context())
    if claims == nil {
        http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
        return
    }
    profile, err := db.GetUser(claims.Subject) // Uses the authenticated user's ID
    if err != nil {
        slog.Error("profile lookup failed", "error", err, "user", claims.Subject)
        http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
        return
    }
    json.NewEncoder(w).Encode(profile)
}
```

**BAD code — Python:**
```python
# BROKEN: No auth check, user ID from request parameter
@app.get("/users/{user_id}/profile")
async def get_profile(user_id: str):
    return await db.get_user(user_id)
```

**GOOD code — Python:**
```python
# SECURE: User ID comes from the verified JWT, not the URL
@app.get("/users/me/profile")
async def get_profile(claims: UserClaims = Depends(require_auth)):
    return await db.get_user(claims.subject)
```

---

### A02: Cryptographic Failures

**Plain English:** Sensitive data is not properly protected — passwords stored in plain text, data sent over unencrypted connections, weak encryption algorithms, keys hardcoded in source code.

**Physical-world analogy:** Writing your bank PIN on a sticky note attached to your debit card. The information exists, but it is not protected in any meaningful way.

**How attackers exploit it:** An attacker intercepts HTTP (not HTTPS) traffic and reads passwords, tokens, and personal data in transit. Or they find a database dump with plaintext passwords and now have credentials for every user. Or they find an API key hardcoded in a public GitHub repo and use it to access paid services.

**What this template does:**
- All secrets go in environment variables (`.env` locally, Doppler in production) — never in code
- Gitleaks scans every commit for leaked secrets
- TLS is enforced for all external communication
- HSTS header tells browsers to always use HTTPS
- The template uses bcrypt/argon2 for password hashing if passwords are involved

**BAD code — Go:**
```go
// BROKEN: Secret hardcoded, HTTP not HTTPS, password stored as plaintext
apiKey := "sk-live-abc123def456"
resp, _ := http.Get("http://api.example.com/data?key=" + apiKey)

func createUser(password string) {
    db.Exec("INSERT INTO users (password) VALUES ($1)", password) // plaintext!
}
```

**GOOD code — Go:**
```go
// SECURE: Secret from env, HTTPS enforced, password hashed
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    log.Fatal("API_KEY environment variable is required")
}
resp, err := http.Get("https://api.example.com/data?key=" + apiKey)

func createUser(password string) error {
    hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
    if err != nil {
        return fmt.Errorf("hash password: %w", err)
    }
    _, err = db.Exec("INSERT INTO users (password_hash) VALUES ($1)", string(hash))
    return err
}
```

**BAD code — Python:**
```python
# BROKEN: Secret in code, HTTP, plaintext password storage
api_key = "sk-live-abc123def456"
resp = requests.get(f"http://api.example.com/data?key={api_key}")

def create_user(password: str):
    cursor.execute("INSERT INTO users (password) VALUES (%s)", (password,))
```

**GOOD code — Python:**
```python
# SECURE: Secret from env, HTTPS, password hashed
import bcrypt

api_key = os.environ["API_KEY"]  # Crashes loud if missing
resp = requests.get(f"https://api.example.com/data?key={api_key}")

def create_user(password: str):
    password_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt())
    cursor.execute(
        "INSERT INTO users (password_hash) VALUES (%s)", (password_hash,)
    )
```

---

### A03: Injection

**Plain English:** An attacker sends malicious input that your application treats as a command instead of as data. The most common type is SQL injection, where user input becomes part of a database query.

**Physical-world analogy:** You are filling out a form at a bank. In the "name" field, you write: `John; please also empty account #9999`. If the bank teller blindly reads whatever is on the form as instructions, they would execute your malicious request. The teller should treat the name field as data, not as a command.

**How attackers exploit it:** An attacker enters `' OR 1=1 --` as their username. If the application builds SQL queries by concatenating strings, this input changes the query's logic — instead of "find the user named X," it becomes "find all users" or worse, "delete all users." The same principle applies to OS commands, LDAP queries, and template engines.

**What this template does:**
- CLAUDE.md Rule 3 mandates parameterized queries for all database operations
- CLAUDE.md Rule 4 bans dangerous functions like `eval()`, `exec()`, `os.system()`, and `subprocess.shell=True`
- Bandit flags string-formatted SQL and dangerous function calls in Python
- CodeQL performs data-flow analysis to find injection paths across function boundaries

**BAD code — Go:**
```go
// BROKEN: SQL injection — user input inserted directly into query string
func GetUser(w http.ResponseWriter, r *http.Request) {
    username := r.URL.Query().Get("username")
    query := fmt.Sprintf("SELECT * FROM users WHERE username = '%s'", username)
    // Attacker sends: username=' OR '1'='1
    // Query becomes: SELECT * FROM users WHERE username = '' OR '1'='1'
    // Result: returns ALL users
    rows, _ := db.Query(query)
    // ...
}
```

**GOOD code — Go:**
```go
// SECURE: Parameterized query — user input is passed as a parameter, not concatenated
func GetUser(w http.ResponseWriter, r *http.Request) {
    username := r.URL.Query().Get("username")
    query := "SELECT id, username, email FROM users WHERE username = $1"
    row := db.QueryRow(query, username)
    // The database driver ensures 'username' is treated as data, never as SQL
    var user User
    if err := row.Scan(&user.ID, &user.Username, &user.Email); err != nil {
        slog.Error("user lookup failed", "error", err)
        http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
        return
    }
    json.NewEncoder(w).Encode(user)
}
```

**BAD code — Python:**
```python
# BROKEN: SQL injection via f-string
@app.get("/users")
async def get_user(username: str):
    cursor.execute(f"SELECT * FROM users WHERE username = '{username}'")
    return cursor.fetchone()
```

**GOOD code — Python:**
```python
# SECURE: Parameterized query — the driver handles escaping
@app.get("/users")
async def get_user(username: str):
    cursor.execute(
        "SELECT id, username, email FROM users WHERE username = %s",
        (username,),
    )
    return cursor.fetchone()
```

---

### A04: Insecure Design

**Plain English:** The application's architecture has fundamental flaws — not bugs in the code, but flaws in the design itself. No amount of perfect code can fix a broken design.

**Physical-world analogy:** A bank vault with a strong door but a window next to it. The lock is excellent, the hinges are reinforced, but the architect forgot that someone could just break the window. The problem is the design, not the implementation.

**How attackers exploit it:** A password reset flow that emails a reset link, but the link contains a predictable token (like the user's email base64-encoded). An attacker can generate reset links for any user without accessing their email. Or an API that returns all fields on a user object, including internal fields like `is_admin`, and accepts those fields on update — letting any user promote themselves to admin.

**What this template does:**
- CLAUDE.md enforces strict input validation with schemas (Go struct tags, Python Pydantic)
- Reject unexpected fields — only accept what you explicitly define
- Principle of least privilege — every endpoint requires auth, specific groups for sensitive operations
- DEV_MODE as an explicit design choice rather than removing auth entirely during development
- Fail closed — when something goes wrong, deny access rather than granting it

**BAD code — Go:**
```go
// BROKEN: Accepts any JSON fields, including internal ones
type UserUpdate struct {
    Name    string `json:"name"`
    Email   string `json:"email"`
    IsAdmin bool   `json:"is_admin"` // Attacker can set this to true!
}

func UpdateUser(w http.ResponseWriter, r *http.Request) {
    var update UserUpdate
    json.NewDecoder(r.Body).Decode(&update)
    db.Exec("UPDATE users SET name=$1, email=$2, is_admin=$3 WHERE id=$4",
        update.Name, update.Email, update.IsAdmin, userID)
}
```

**GOOD code — Go:**
```go
// SECURE: Only accept fields the user is allowed to change
type UserUpdate struct {
    Name  string `json:"name" validate:"required,min=1,max=100"`
    Email string `json:"email" validate:"required,email"`
    // is_admin is NOT in this struct — users cannot set it
}

func UpdateUser(w http.ResponseWriter, r *http.Request) {
    var update UserUpdate
    if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
        http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
        return
    }
    if err := validate.Struct(update); err != nil {
        http.Error(w, `{"error":"validation failed"}`, http.StatusBadRequest)
        return
    }
    claims := middleware.UserFromContext(r.Context())
    db.Exec("UPDATE users SET name=$1, email=$2 WHERE id=$3",
        update.Name, update.Email, claims.Subject)
}
```

**BAD code — Python:**
```python
# BROKEN: Accepts arbitrary dict, updates all fields
@app.put("/users/me")
async def update_user(request: Request):
    data = await request.json()  # Could contain {"is_admin": true}
    await db.execute(
        "UPDATE users SET " +
        ", ".join(f"{k}=:{k}" for k in data.keys()) +
        " WHERE id=:id",
        {**data, "id": current_user.id},
    )
```

**GOOD code — Python:**
```python
# SECURE: Pydantic model defines exactly which fields are allowed
from pydantic import BaseModel, EmailStr

class UserUpdate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    # is_admin is NOT in this model — users cannot set it

@app.put("/users/me")
async def update_user(
    update: UserUpdate,
    claims: UserClaims = Depends(require_auth),
):
    await db.execute(
        "UPDATE users SET name=:name, email=:email WHERE id=:id",
        {"name": update.name, "email": update.email, "id": claims.subject},
    )
```

---

### A05: Security Misconfiguration

**Plain English:** The application or server is configured in a way that leaves it vulnerable — debug mode enabled in production, default passwords unchanged, unnecessary features turned on, verbose error messages exposed to users.

**Physical-world analogy:** Moving into a new house and never changing the locks. The builder, the realtor, and the previous owner all still have keys. The house is structurally fine — it is just configured insecurely.

**How attackers exploit it:** An attacker finds that the app's Swagger/OpenAPI docs page is publicly accessible at `/docs`, revealing every endpoint and parameter. Or they trigger an error and get a full stack trace showing file paths, library versions, and database connection strings. Or they discover that CORS is set to `*`, allowing any website to make authenticated requests to the API.

**What this template does:**
- FastAPI docs disabled by default (`docs_url=None, redoc_url=None`)
- CORS restricted to explicit origins from environment variables — never `*`
- TrustedHostMiddleware limits which hostnames the app responds to
- Security headers on every response (X-Content-Type-Options, X-Frame-Options, CSP, HSTS)
- Generic error messages to users, detailed errors to internal logs only
- HTTP server timeouts explicitly set (ReadTimeout, WriteTimeout, IdleTimeout)
- The doctor script (`make doctor`) checks for misconfigurations

**BAD code — Go:**
```go
// BROKEN: No timeouts, no CORS restrictions, debug info in errors
srv := &http.Server{
    Addr:    ":8080",
    Handler: mux,
    // No ReadTimeout, WriteTimeout, IdleTimeout — vulnerable to slowloris attacks
}

func handler(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Access-Control-Allow-Origin", "*") // Any website can call this
    result, err := db.Query("SELECT * FROM data")
    if err != nil {
        http.Error(w, err.Error(), 500) // Leaks internal error details
        return
    }
}
```

**GOOD code — Go:**
```go
// SECURE: Explicit timeouts, restricted CORS, generic errors
srv := &http.Server{
    Addr:         ":" + port,
    Handler:      handler,
    ReadTimeout:  15 * time.Second,
    WriteTimeout: 15 * time.Second,
    IdleTimeout:  60 * time.Second,
}

func handler(w http.ResponseWriter, r *http.Request) {
    origin := os.Getenv("CORS_ORIGINS") // e.g., "https://dashboard.internal.coreweave.com"
    w.Header().Set("Access-Control-Allow-Origin", origin)
    w.Header().Set("X-Content-Type-Options", "nosniff")
    w.Header().Set("X-Frame-Options", "DENY")
    w.Header().Set("Content-Security-Policy", "default-src 'self'")

    result, err := db.Query("SELECT id, name FROM data WHERE active = true")
    if err != nil {
        slog.Error("database query failed", "error", err)
        http.Error(w, `{"error":"internal server error"}`, 500)
        return
    }
}
```

**BAD code — Python:**
```python
# BROKEN: Debug mode on, CORS wide open, docs exposed
app = FastAPI()  # docs_url defaults to /docs — publicly accessible

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Any website can make requests
    allow_methods=["*"],
    allow_headers=["*"],
)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8080, debug=True)  # Debug in production!
```

**GOOD code — Python:**
```python
# SECURE: Docs disabled, CORS restricted, no debug mode
app = FastAPI(docs_url=None, redoc_url=None)

app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=os.environ.get("ALLOWED_HOSTS", "localhost").split(","),
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.environ.get("CORS_ORIGINS", "").split(","),
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization"],
)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")))
```

---

### A06: Vulnerable and Outdated Components

**Plain English:** Your application uses third-party libraries that have known security holes. Attackers do not need to find new vulnerabilities — they just check which libraries you use and look up the existing exploits.

**Physical-world analogy:** Using a door lock that was recalled six months ago because a YouTube video showed how to open it with a credit card. The lock manufacturer published a fix, but you never installed it.

**How attackers exploit it:** An attacker scans your application (or reads your SBOM) and finds you are using a version of a library with a known remote code execution vulnerability. They download the public exploit and run it. This is the most common attack vector because it requires the least skill — the exploit is pre-built, they just point and shoot.

**What this template does:**
- All dependency versions are pinned in `go.mod` and `pyproject.toml` — no floating version ranges
- CI runs `govulncheck` (Go) and `pip-audit` (Python) against vulnerability databases on every PR
- CI generates an SBOM (Software Bill of Materials) as a build artifact
- CLAUDE.md Rule 7 requires justification comments for every new dependency
- Dependencies should be well-maintained, widely-used, and minimized (prefer stdlib)

**BAD code — Go:**
```go
// BROKEN: go.mod with loose version constraints and unnecessary dependencies
module myapp

go 1.22

require (
    github.com/some-abandoned-lib v0.0.1  // Last updated 2019, known CVEs
    github.com/kitchen-sink-framework v2.0.0  // Massive dependency with features you do not use
)
```

**GOOD code — Go:**
```go
// SECURE: Pinned versions, minimal dependencies, each one justified
module myapp

go 1.22

require (
    // Structured logging — stdlib slog does not support all our output formats yet
    github.com/well-maintained/slog-handler v1.4.2
)
```

**BAD code — Python:**
```python
# BROKEN: pyproject.toml with floating versions
[project]
dependencies = [
    "requests",           # No version pin — could pull a compromised release
    "flask>=2.0",         # Floating range — could get a version with known CVEs
    "some-obscure-lib",   # 12 GitHub stars, last commit 2020
]
```

**GOOD code — Python:**
```python
# SECURE: Exact version pins, each dependency justified
[project]
dependencies = [
    "fastapi==0.115.6",       # Web framework — async, Pydantic validation built-in
    "uvicorn[standard]==0.34.0",  # ASGI server for FastAPI
    "httpx==0.28.1",          # HTTP client — async support, connection pooling
]
```

---

### A07: Identification and Authentication Failures

**Plain English:** The application's login system is broken — it allows weak passwords, does not prevent brute-force attempts, stores credentials insecurely, or has flaws in session management.

**Physical-world analogy:** A building where the security guard checks IDs, but accepts photocopies, does not check the photo against your face, and lets you in unlimited times even after you show the wrong ID ten times in a row.

**How attackers exploit it:** Credential stuffing — the attacker has a list of millions of username/password combos from other breaches and tries them all against your login. Without rate limiting, they can try thousands per second. Or session hijacking — the attacker steals a session token from a cookie stored insecurely and impersonates the user. Or a custom authentication system has a flaw (password comparison is case-insensitive, reset tokens are predictable, etc.).

**What this template does:**
- No custom authentication — Okta OIDC handles all login, password policies, MFA, and session management
- JWT verification with full validation: signature, expiry, issuer, audience, algorithm whitelist (RS256 only)
- JWKS key rotation handled automatically with cache refresh
- Rate limiting on all endpoints (100 req/min default) prevents brute-force
- Session tokens in httpOnly cookies (for web apps), never in localStorage
- DEV_MODE for local development instead of removing auth

**BAD code — Go:**
```go
// BROKEN: Hand-rolled auth with multiple flaws
func Login(w http.ResponseWriter, r *http.Request) {
    username := r.FormValue("username")
    password := r.FormValue("password")

    var storedPassword string
    db.QueryRow("SELECT password FROM users WHERE username = $1", username).Scan(&storedPassword)

    if password == storedPassword { // Plaintext comparison!
        token := base64.StdEncoding.EncodeToString([]byte(username)) // Predictable token!
        http.SetCookie(w, &http.Cookie{
            Name:  "session",
            Value: token,
            // Missing: HttpOnly, Secure, SameSite
        })
    }
}
```

**GOOD code — Go:**
```go
// SECURE: Use Okta OIDC — do not build your own auth
// In main.go, wire the RequireAuth middleware:
mux := http.NewServeMux()
mux.Handle("/api/", middleware.RequireAuth(apiHandler))
mux.HandleFunc("/healthz", healthHandler) // Health check is unauthenticated

// The middleware handles:
// - JWT signature verification against Okta's JWKS
// - Token expiry, issuer, and audience validation
// - Algorithm whitelist (RS256 only)
// - Automatic JWKS key rotation
// - DEV_MODE bypass with loud warnings for local dev
```

**BAD code — Python:**
```python
# BROKEN: Custom auth with predictable tokens and no rate limiting
@app.post("/login")
async def login(username: str, password: str):
    user = await db.get_user(username)
    if user and user.password == password:  # Plaintext comparison!
        token = base64.b64encode(username.encode()).decode()  # Predictable!
        return {"token": token}
    return {"error": "invalid credentials"}, 401
```

**GOOD code — Python:**
```python
# SECURE: Use Okta OIDC — the verify_token dependency handles everything
from middleware.auth import require_auth, UserClaims

@app.get("/api/data")
async def get_data(claims: UserClaims = Depends(require_auth)):
    # claims.subject, claims.email, claims.groups are already verified
    return {"message": f"Hello, {claims.email}"}

# Auth is handled by Okta — login page, MFA, password policy, session management
# are all Okta's responsibility. Your app never sees or stores passwords.
```

---

### A08: Software and Data Integrity Failures

**Plain English:** Your application trusts data or software updates without verifying they have not been tampered with — unsigned packages, unverified CI artifacts, deserialization of untrusted data.

**Physical-world analogy:** Accepting a package left on your doorstep with no return address, no tracking number, and no tamper-evident seal. You do not know who sent it, when it was sent, or if someone opened it and added something along the way.

**How attackers exploit it:** Supply chain attacks — an attacker compromises a popular open-source library and publishes a malicious version. If your CI pulls `latest` instead of a pinned version, you deploy the compromised code automatically. Or deserialization attacks — if your Python app uses `pickle.loads()` on data from an API, an attacker can craft a pickle payload that executes arbitrary code when deserialized.

**What this template does:**
- All dependency versions are pinned (not floating ranges)
- CI generates SBOMs for auditability
- CodeQL analyzes data integrity patterns
- CLAUDE.md bans `pickle.loads()` on untrusted data, `yaml.load()` (use `yaml.safe_load()`), and other unsafe deserialization
- Hook integrity check in CI prevents weakening security configs
- Container images use Chainguard base images from CoreWeave's internal catalog

**BAD code — Go:**
```go
// BROKEN: Deserializes arbitrary data from external source without validation
func ProcessWebhook(w http.ResponseWriter, r *http.Request) {
    var payload map[string]interface{} // Accepts absolutely anything
    json.NewDecoder(r.Body).Decode(&payload)
    // No signature verification — anyone can send fake webhooks
    processEvent(payload)
}
```

**GOOD code — Go:**
```go
// SECURE: Validates webhook signature and uses strict type
type WebhookEvent struct {
    Type string `json:"type" validate:"required,oneof=user.created user.updated"`
    Data struct {
        UserID string `json:"user_id" validate:"required,uuid"`
    } `json:"data"`
}

func ProcessWebhook(w http.ResponseWriter, r *http.Request) {
    // Verify HMAC signature from the webhook provider
    signature := r.Header.Get("X-Webhook-Signature")
    body, _ := io.ReadAll(io.LimitReader(r.Body, 1<<20))
    if !verifyHMAC(body, signature, os.Getenv("WEBHOOK_SECRET")) {
        http.Error(w, `{"error":"invalid signature"}`, http.StatusUnauthorized)
        return
    }

    var event WebhookEvent
    if err := json.Unmarshal(body, &event); err != nil {
        http.Error(w, `{"error":"invalid payload"}`, http.StatusBadRequest)
        return
    }
    if err := validate.Struct(event); err != nil {
        http.Error(w, `{"error":"validation failed"}`, http.StatusBadRequest)
        return
    }
    processEvent(event)
}
```

**BAD code — Python:**
```python
# BROKEN: Deserializes untrusted pickle data — remote code execution!
import pickle

@app.post("/process")
async def process_data(request: Request):
    body = await request.body()
    data = pickle.loads(body)  # Attacker controls the bytes = arbitrary code execution
    return {"result": str(data)}
```

**GOOD code — Python:**
```python
# SECURE: Use JSON (safe) instead of pickle (dangerous), with strict schema
from pydantic import BaseModel

class ProcessRequest(BaseModel):
    items: list[str]
    action: str = Field(pattern=r"^(count|sort|filter)$")

@app.post("/process")
async def process_data(req: ProcessRequest):
    # Pydantic validates the structure and content before we touch it
    return {"result": len(req.items)}
```

---

### A09: Security Logging and Monitoring Failures

**Plain English:** Your application does not keep adequate records of what happens — who logged in, who was denied access, what errors occurred. Without logs, you cannot detect an attack in progress or investigate one after the fact.

**Physical-world analogy:** A bank with no security cameras. If money goes missing, there is no footage to review. The robbery might have happened yesterday, or it might be happening right now — you would not know either way.

**How attackers exploit it:** An attacker knows that if there are no logs, there is no detection. They can probe the system slowly, escalate privileges gradually, and exfiltrate data without triggering any alerts. By the time someone notices, the trail is cold. Some attackers specifically delete or tamper with logs to cover their tracks.

**What this template does:**
- Structured JSON logging (Go `slog`, Python `structlog`/`logging`)
- Every request gets a unique `X-Request-ID` for distributed tracing
- Auth events are always logged: successful login, failed login, permission denied
- Input validation failures are logged
- Secrets are never logged — the logging rules explicitly ban logging `Authorization` headers, cookie values, passwords, tokens, API keys, and PII
- Generic error messages returned to users; full details logged internally

**BAD code — Go:**
```go
// BROKEN: Logs the secret, does not log the auth failure, no request ID
func handler(w http.ResponseWriter, r *http.Request) {
    token := r.Header.Get("Authorization")
    fmt.Printf("Request with auth: %s\n", token) // LEAKS THE TOKEN

    user, err := verifyToken(token)
    if err != nil {
        // Auth failure not logged — attacker brute-forces undetected
        http.Error(w, "unauthorized", 401)
        return
    }
}
```

**GOOD code — Go:**
```go
// SECURE: Structured logging, no secret exposure, auth events tracked
func handler(w http.ResponseWriter, r *http.Request) {
    requestID := r.Header.Get("X-Request-ID")
    if requestID == "" {
        requestID = uuid.NewString()
    }

    // Log that auth was present, not the token value
    slog.Info("request received",
        "request_id", requestID,
        "path", r.URL.Path,
        "method", r.Method,
        "authenticated", r.Header.Get("Authorization") != "",
    )

    user, err := verifyToken(r.Header.Get("Authorization"))
    if err != nil {
        // Auth failures are ALWAYS logged — this is how you detect brute-force
        slog.Warn("authentication failed",
            "request_id", requestID,
            "error", err,
            "path", r.URL.Path,
            "remote_addr", r.RemoteAddr,
        )
        http.Error(w, `{"error":"unauthorized"}`, 401)
        return
    }
    slog.Info("authenticated", "request_id", requestID, "user", user.Subject)
}
```

**BAD code — Python:**
```python
# BROKEN: Prints secrets, ignores auth failures
@app.post("/login")
async def login(request: Request):
    body = await request.json()
    print(f"Login attempt: {body}")  # Logs username AND password!

    user = await authenticate(body["username"], body["password"])
    if not user:
        return {"error": "bad credentials"}, 401  # No logging = no detection
    return {"token": create_token(user)}
```

**GOOD code — Python:**
```python
# SECURE: Structured logging, never log passwords, always log auth events
import structlog

logger = structlog.get_logger()

@app.post("/login")
async def login(creds: LoginRequest, request: Request):
    user = await authenticate(creds.username, creds.password)
    if not user:
        # Always log auth failures — this detects brute-force attacks
        logger.warning(
            "authentication_failed",
            username=creds.username,  # Log the username, NEVER the password
            remote_addr=request.client.host,
            path=request.url.path,
        )
        return JSONResponse({"error": "bad credentials"}, status_code=401)

    logger.info(
        "authentication_success",
        username=creds.username,
        user_id=user.id,
    )
    return {"token": create_token(user)}
```

---

### A10: Server-Side Request Forgery (SSRF)

**Plain English:** An attacker tricks your server into making requests to internal systems that the attacker cannot reach directly. Your server acts as a proxy for the attacker.

**Physical-world analogy:** You work inside a secure building with access to the filing cabinet room. Someone outside calls you and says, "Can you go to the filing cabinet, pull out file #12345, and read it to me over the phone?" If you do not verify who is calling or whether they should have access to that file, you have just been used as an insider.

**How attackers exploit it:** The attacker finds an endpoint that fetches a URL — maybe an avatar upload that accepts a URL, or a webhook configuration, or an API that fetches remote data. Instead of a normal URL, they provide `http://169.254.169.254/latest/meta-data/` (the cloud metadata service), or `http://internal-database:5432/`, or `http://localhost:8080/admin/delete-all`. The server makes the request from inside the network, bypassing firewalls and network policies.

**What this template does:**
- CLAUDE.md prohibits user-controlled fetch targets without validation
- All outbound URLs must be validated against an allowlist
- Internal service communication uses service mesh / network policies, not user-supplied URLs
- Rate limiting and request size limits reduce the effectiveness of SSRF probing
- The deployment uses Traefik internal ingress and network policies to limit blast radius

**BAD code — Go:**
```go
// BROKEN: Fetches any URL the user provides — SSRF
func FetchPreview(w http.ResponseWriter, r *http.Request) {
    targetURL := r.URL.Query().Get("url")
    resp, err := http.Get(targetURL) // Attacker sends url=http://169.254.169.254/...
    if err != nil {
        http.Error(w, "fetch failed", 500)
        return
    }
    defer resp.Body.Close()
    io.Copy(w, resp.Body) // Returns cloud metadata, internal service data, etc.
}
```

**GOOD code — Go:**
```go
// SECURE: Validate URL against allowlist, block internal addresses
var allowedHosts = map[string]bool{
    "api.example.com":      true,
    "cdn.example.com":      true,
}

func FetchPreview(w http.ResponseWriter, r *http.Request) {
    targetURL := r.URL.Query().Get("url")

    parsed, err := url.Parse(targetURL)
    if err != nil || parsed.Scheme != "https" {
        http.Error(w, `{"error":"invalid URL"}`, http.StatusBadRequest)
        return
    }

    // Block internal/private IP ranges and cloud metadata
    if !allowedHosts[parsed.Hostname()] {
        slog.Warn("SSRF attempt blocked", "url", targetURL, "host", parsed.Hostname())
        http.Error(w, `{"error":"URL not in allowlist"}`, http.StatusForbidden)
        return
    }

    client := &http.Client{Timeout: 5 * time.Second}
    resp, err := client.Get(targetURL)
    if err != nil {
        http.Error(w, `{"error":"fetch failed"}`, http.StatusBadGateway)
        return
    }
    defer resp.Body.Close()
    io.Copy(w, io.LimitReader(resp.Body, 1<<20)) // 1MB limit
}
```

**BAD code — Python:**
```python
# BROKEN: Fetches any URL — SSRF vulnerability
@app.get("/preview")
async def fetch_preview(url: str):
    resp = requests.get(url)  # Attacker sends url=http://169.254.169.254/...
    return {"content": resp.text}
```

**GOOD code — Python:**
```python
# SECURE: Validate against allowlist, block internal addresses
from urllib.parse import urlparse

ALLOWED_HOSTS = {"api.example.com", "cdn.example.com"}

@app.get("/preview")
async def fetch_preview(url: str):
    parsed = urlparse(url)
    if parsed.scheme != "https":
        return JSONResponse({"error": "HTTPS required"}, status_code=400)

    if parsed.hostname not in ALLOWED_HOSTS:
        logger.warning("ssrf_attempt_blocked", url=url, host=parsed.hostname)
        return JSONResponse({"error": "URL not in allowlist"}, status_code=403)

    async with httpx.AsyncClient(timeout=5.0) as client:
        resp = await client.get(url)
    return {"content": resp.text[:10000]}  # Limit response size
```

---

## 4. 10 Common Mistakes

These are the mistakes we see most often in internal tools. Each one is caught by this template's pipeline, but understanding them helps you write better code from the start.

---

### Mistake 1: Hardcoding Secrets

**The problem:** API keys, database passwords, and tokens embedded directly in source code. Once committed to git, the secret exists in the repository history forever — even if you delete it in the next commit.

**How the pipeline catches it:** Gitleaks in pre-commit hooks and CI scans every commit for patterns that look like secrets (API keys, tokens, connection strings).

**Do this instead:** Store all secrets in environment variables. Use `.env` files locally (gitignored), Doppler in production. Add every new variable to `.env.example` with a placeholder value.

```go
// WRONG
apiKey := "sk-live-abc123def456ghi789"

// RIGHT
apiKey := os.Getenv("API_KEY")
if apiKey == "" {
    log.Fatal("API_KEY environment variable is required")
}
```

```python
# WRONG
api_key = "sk-live-abc123def456ghi789"

# RIGHT
api_key = os.environ["API_KEY"]  # Crashes immediately if missing
```

---

### Mistake 2: Skipping Authentication

**The problem:** Internal tools often start with "we'll add auth later" and never do. Every unauthenticated endpoint is accessible to anyone on the network.

**How the pipeline catches it:** CLAUDE.md enforces auth on every endpoint. The PR security checklist includes "Auth applied — new endpoints require authentication (Okta OIDC)."

**Do this instead:** Wire the RequireAuth middleware from the start. Use `DEV_MODE=true` in your `.env` for local development — it injects a fake test user so your app behaves like it has auth, without needing real Okta credentials.

---

### Mistake 3: Using eval() or exec()

**The problem:** `eval()` and `exec()` execute arbitrary code. If any part of the input is influenced by a user, the attacker can run any code they want on your server.

**How the pipeline catches it:** Bandit flags `eval()`, `exec()`, `compile()`, and `os.system()`. CLAUDE.md Rule 4 bans them outright.

**Do this instead:** Use structured data processing. Parse JSON, use dictionaries for dispatch, or use safe alternatives.

```python
# WRONG — Remote code execution if user controls "expression"
result = eval(expression)

# RIGHT — Use a safe mapping
operations = {"add": lambda a, b: a + b, "sub": lambda a, b: a - b}
result = operations.get(operation, lambda a, b: None)(a, b)
```

```go
// WRONG — Runs arbitrary shell commands
cmd := exec.Command("sh", "-c", userInput)

// RIGHT — Use specific command with arguments as a list
cmd := exec.Command("ls", "-la", sanitizedPath)
```

---

### Mistake 4: SQL String Concatenation

**The problem:** Building SQL queries by concatenating user input directly into the query string. This is the number one cause of SQL injection.

**How the pipeline catches it:** Bandit and gosec flag string-formatted SQL. CodeQL traces data flow from user input to SQL execution. CLAUDE.md Rule 3 mandates parameterized queries.

**Do this instead:** Always use parameterized queries (also called prepared statements). The database driver treats parameters as data, never as SQL commands.

```go
// WRONG
query := fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", name)

// RIGHT
query := "SELECT * FROM users WHERE name = $1"
row := db.QueryRow(query, name)
```

```python
# WRONG
cursor.execute(f"SELECT * FROM users WHERE name = '{name}'")

# RIGHT
cursor.execute("SELECT * FROM users WHERE name = %s", (name,))
```

---

### Mistake 5: Disabling TLS Verification

**The problem:** Setting `InsecureSkipVerify: true` (Go) or `verify=False` (Python) disables certificate validation. This means you cannot tell if you are talking to the real server or an attacker performing a man-in-the-middle attack.

**How the pipeline catches it:** The doctor script scans for `InsecureSkipVerify: true`. Bandit and gosec flag disabled TLS verification. CLAUDE.md Rule 6 enforces HTTPS everywhere.

**Do this instead:** Fix the underlying certificate issue. If you need to disable TLS for a local development server, gate it behind an environment variable and add a TODO to remove it.

```go
// WRONG
client := &http.Client{
    Transport: &http.Transport{
        TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
    },
}

// RIGHT — fix the cert issue, or gate behind env var for dev only
if os.Getenv("DISABLE_TLS_VERIFY") == "true" {
    slog.Warn("TLS verification disabled — DO NOT USE IN PRODUCTION")
    // TODO: Remove before production deployment
}
```

```python
# WRONG
resp = requests.get(url, verify=False)

# RIGHT
resp = requests.get(url)  # verify=True is the default — just do not override it
```

---

### Mistake 6: Using --no-verify on Git Commits

**The problem:** `git commit --no-verify` skips all pre-commit hooks — the secret scanner, the linter, the security scanner, everything. It is the "bypass all security" button.

**How the pipeline catches it:** The CI hook-integrity job checks that `.last-hook-run` is recent. If you skipped hooks, the timestamp is stale, and CI blocks your PR. The pre-commit hook writes a timestamp every time it runs — so skipping it leaves an evidence trail.

**Do this instead:** Fix whatever the hook is complaining about. Run `make fix` to auto-fix what it can, or `make doctor` to diagnose the issue. If a hook is genuinely wrong (false positive), open a PR to update the hook configuration — do not bypass it.

---

### Mistake 7: Setting CORS to *

**The problem:** `Access-Control-Allow-Origin: *` means any website on the internet can make requests to your API from a user's browser, using that user's cookies. This is how cross-site attacks work — a malicious website makes requests to your API on behalf of the user.

**How the pipeline catches it:** CLAUDE.md explicitly prohibits `CORS *`. The template sets CORS from the `CORS_ORIGINS` environment variable, which you configure to your specific frontend domain.

**Do this instead:** Set CORS to the specific origin(s) that need access.

```go
// WRONG
w.Header().Set("Access-Control-Allow-Origin", "*")

// RIGHT
origin := os.Getenv("CORS_ORIGINS") // "https://dashboard.internal.coreweave.com"
w.Header().Set("Access-Control-Allow-Origin", origin)
```

```python
# WRONG
allow_origins=["*"]

# RIGHT
allow_origins=os.environ.get("CORS_ORIGINS", "").split(",")
```

---

### Mistake 8: Logging Secrets

**The problem:** Logging `Authorization` headers, request bodies with passwords, API keys, or PII. These logs end up in monitoring systems, log aggregators, and backups — expanding the attack surface far beyond the application itself.

**How the pipeline catches it:** CLAUDE.md Logging Rules explicitly ban logging passwords, tokens, API keys, PII, `Authorization` headers, and cookie values. Code review checklist item: "Secrets not logged."

**Do this instead:** Log that something is present, not the value itself. Log the user's identity after verifying it, not the raw credential.

```go
// WRONG
slog.Info("request", "auth_header", r.Header.Get("Authorization"))

// RIGHT
slog.Info("request", "authenticated", r.Header.Get("Authorization") != "")
```

```python
# WRONG
logger.info("login attempt", password=creds.password, token=token)

# RIGHT
logger.info("login attempt", username=creds.username, has_token=bool(token))
```

---

### Mistake 9: Using pickle on Untrusted Data

**The problem:** Python's `pickle` module can deserialize arbitrary Python objects — including objects that execute code when deserialized. If an attacker can control the input to `pickle.loads()`, they can run any code on your server.

**How the pipeline catches it:** Bandit flags `pickle.loads()`. CLAUDE.md Rule 4 bans it for untrusted data.

**Do this instead:** Use JSON for data interchange. If you need to serialize complex Python objects, use a safe format like `msgpack` or `protobuf`. If you must use pickle, only on data you generated and stored yourself — never on data from an API, user upload, or external service.

```python
# WRONG — remote code execution
import pickle
data = pickle.loads(request_body)

# RIGHT — safe deserialization
import json
data = json.loads(request_body)
```

---

### Mistake 10: Not Validating Input

**The problem:** Accepting user input without checking its type, length, format, or range. This is the root cause of injection, overflow, and logic bugs.

**How the pipeline catches it:** CLAUDE.md Rule 3 mandates server-side validation on all input. The template provides Pydantic (Python) and struct tags + validator (Go) for schema-based validation. CodeQL detects data flowing from input to sensitive operations without validation.

**Do this instead:** Define a strict schema for every input. Reject anything that does not match. Validate on the server, not the client (client-side validation is a UX convenience, not a security measure).

```go
// WRONG — accepts any values, no validation
type CreateUser struct {
    Name  string
    Email string
    Age   int
}

// RIGHT — strict validation rules
type CreateUser struct {
    Name  string `json:"name" validate:"required,min=1,max=100,alphanumunicode"`
    Email string `json:"email" validate:"required,email"`
    Age   int    `json:"age" validate:"required,min=13,max=150"`
}
```

```python
# WRONG — accepts anything
@app.post("/users")
async def create_user(request: Request):
    data = await request.json()
    name = data.get("name")  # Could be None, could be 10MB of data, could be HTML

# RIGHT — strict Pydantic schema
from pydantic import BaseModel, Field, EmailStr

class CreateUser(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    email: EmailStr
    age: int = Field(ge=13, le=150)

@app.post("/users")
async def create_user(user: CreateUser):
    # Pydantic already validated everything — user.name is guaranteed to be
    # a string between 1 and 100 characters. Invalid requests never reach this code.
    pass
```

---

## 5. Glossary

**CORS (Cross-Origin Resource Sharing)** — A browser security mechanism that controls which websites can make requests to your API. By default, browsers block cross-origin requests. CORS headers tell the browser which origins are allowed. Setting it to `*` allows all origins, which defeats the purpose.

**CodeQL** — GitHub's static analysis engine that finds vulnerabilities by tracing how data flows through your code. Unlike simple pattern matching (grep for `eval`), CodeQL understands that user input flows through function A, gets transformed in function B, and reaches a SQL query in function C. It catches the injection even if no single line looks dangerous.

**CSP (Content Security Policy)** — An HTTP header that tells browsers which sources of content (scripts, styles, images, fonts) are allowed on your page. It prevents cross-site scripting (XSS) by blocking scripts that did not come from trusted sources. `default-src 'self'` means "only allow content from the same domain."

**CSRF (Cross-Site Request Forgery)** — An attack where a malicious website makes your browser send a request to a site where you are logged in, using your cookies. It works because cookies are sent automatically with every request to the domain. CSRF tokens prevent this by requiring a secret value that the malicious site does not have.

**Defense in Depth** — A security strategy that layers multiple independent safeguards. If one layer fails, others still protect the system. In this template: AI guardrails, git hooks, CI checks, code review, and infrastructure controls are all independent layers.

**DEV_MODE** — An environment variable (`DEV_MODE=true`) that enables a local development bypass for authentication. Instead of requiring real Okta credentials, it injects a fake test user. It logs loud warnings on every request so it is impossible to accidentally deploy in this mode.

**Doppler** — A secrets management platform used at CoreWeave. In production, application secrets (API keys, database passwords, etc.) are stored in Doppler and injected into Kubernetes pods via External Secrets Operator. Secrets never exist in git or in container images.

**ESO (External Secrets Operator)** — A Kubernetes operator that syncs secrets from external providers (like Doppler) into Kubernetes Secret objects. Your deployment references the ESO resource, and ESO keeps the actual secret values in sync. This means your Helm charts never contain secret values.

**HSTS (HTTP Strict Transport Security)** — An HTTP header (`Strict-Transport-Security: max-age=31536000`) that tells browsers to always use HTTPS for your domain, even if the user types `http://`. Once a browser sees this header, it refuses to make HTTP requests to your domain for the duration of `max-age` (31536000 seconds = 1 year).

**JWT (JSON Web Token)** — A compact, URL-safe token format used for authentication. It has three parts: a header (algorithm, key ID), a payload (user info, expiry), and a signature (proof the token was issued by the identity provider). JWTs are signed but not encrypted — anyone can read the payload, but nobody can tamper with it without invalidating the signature.

**JWKS (JSON Web Key Set)** — A set of public keys published by the identity provider (Okta) at a well-known URL. Your app uses these keys to verify JWT signatures. Keys rotate periodically, so the app refreshes the JWKS cache to pick up new keys.

**Okta** — CoreWeave's identity provider. Okta handles user login, multi-factor authentication, password policies, and group management. Your app delegates all authentication to Okta via OIDC and never handles passwords directly.

**OIDC (OpenID Connect)** — A protocol built on top of OAuth2 that handles user authentication. When a user logs in, Okta issues a JWT containing the user's identity claims (email, name, groups). Your app verifies this JWT instead of managing its own login system.

**Parameterized Query** — A SQL query where user input is passed as a separate parameter, not concatenated into the query string. The database driver ensures the parameter is treated as data, never as SQL syntax. This is the primary defense against SQL injection.

**Rate Limiting** — Restricting the number of requests a client can make in a given time window. Default in this template: 100 requests per minute per IP. Prevents brute-force attacks, denial of service, and abuse. Returns HTTP 429 (Too Many Requests) with a `Retry-After` header when exceeded.

**RBAC (Role-Based Access Control)** — Granting permissions based on group membership rather than individual user assignments. In this template, Okta group claims (e.g., `admin`, `viewer`, `editor`) determine what a user can do. Adding or removing access is done in Okta, not in code.

**SAST (Static Application Security Testing)** — Analyzing source code for vulnerabilities without running the application. Tools in this template: gosec (Go), bandit (Python), CodeQL (both). SAST catches patterns like hardcoded secrets, SQL injection, and dangerous function calls.

**SBOM (Software Bill of Materials)** — A complete list of every third-party component (library, framework, module) used in your application, including their versions. The CI pipeline generates SBOMs automatically. They enable rapid response when a vulnerability is discovered in a dependency — you can immediately see which apps are affected.

**SCA (Software Composition Analysis)** — Scanning your dependencies against databases of known vulnerabilities. Tools in this template: govulncheck (Go), pip-audit (Python). Unlike SAST which analyzes your code, SCA analyzes the code you imported.

**SSRF (Server-Side Request Forgery)** — An attack where an attacker tricks your server into making HTTP requests to internal systems. If your app fetches a URL provided by the user, the attacker can use it to access cloud metadata, internal databases, or other services behind the firewall.

**TLS (Transport Layer Security)** — Encryption for data in transit. When you use HTTPS, TLS encrypts the connection between the client and server so that anyone intercepting the traffic sees only encrypted bytes. Disabling TLS verification (`InsecureSkipVerify`, `verify=False`) defeats this protection entirely.

**XSS (Cross-Site Scripting)** — An attack where an attacker injects malicious JavaScript into a page that other users view. If your app displays user input without sanitizing it (e.g., rendering a username that contains `<script>alert('hacked')</script>`), the script runs in every visitor's browser, stealing cookies, tokens, or PII.

---

## 6. FAQ

### 1. Can I disable the pre-commit hooks?

No, and the pipeline is designed to make this pointless even if you try. If you uninstall the hooks, they re-install on the next `git checkout` (via the post-checkout hook). If you delete the hook files, `make setup` reinstalls them. If you use `git commit --no-verify` to skip them entirely, the CI hook-integrity job detects the stale `.last-hook-run` timestamp and blocks your PR. The hooks are there to save you from committing secrets — a mistake that is painful and expensive to undo (secrets in git history require a full repo rewrite to remove).

### 2. Why can I not commit directly to main?

The `no-commit-to-branch` pre-commit hook blocks direct commits to `main` and `master`. This forces all changes through the pull request process, which includes CI checks, code review, and the security checklist. Even if you are the only person working on the project, PRs create an audit trail and give the automated tools a chance to catch issues before they land. Create a feature branch: `git checkout -b feature/my-change`.

### 3. What is DEV_MODE?

`DEV_MODE=true` is an environment variable you set in your local `.env` file. When enabled, the authentication middleware injects a fake test user instead of requiring a real Okta JWT. This lets you develop and test locally without Okta credentials. It logs a loud warning on every request (`DEV_MODE: authentication bypassed -- DO NOT USE IN PRODUCTION`). In CI and production, `DEV_MODE` is never set, so real authentication is enforced. The fake user has `admin` group membership, so you can test all RBAC paths locally.

### 4. What do I do when a security scan gives a false positive?

First, make sure it is actually a false positive — most "false positives" are real issues that seem harmless in context but would be dangerous if the context changed. If it is genuinely wrong, you have two options: (a) add an inline suppression comment (`// nolint:gosec` in Go, `# nosec` for bandit in Python) with a comment explaining why it is safe, or (b) update the scanner configuration (`.golangci.yml` or `bandit.yaml`) to exclude the specific pattern. Both approaches are auditable — reviewers can see and question suppressions. Never suppress without an explanation.

### 5. I need to add a new dependency. What is the process?

1. Check if the Go or Python standard library can do the job first. Fewer dependencies = smaller attack surface.
2. Verify the library is well-maintained: recent commits, active maintainers, significant usage (stars, downloads).
3. Pin the exact version in `go.mod` or `pyproject.toml` — no floating ranges like `>=2.0`.
4. Add a comment in the dependency file explaining why this library is needed.
5. CI will automatically run `govulncheck` / `pip-audit` to check the dependency against known vulnerability databases.
6. The PR security checklist item "Dependencies justified" reminds reviewers to verify your addition.

### 6. How do I get Okta credentials for my app?

Okta applications are registered through IT. File a Freshservice ticket requesting a new Okta OIDC application. Include: your app name, app type (web app or CLI), grant type (Authorization Code for web, Device Authorization for CLI), redirect URIs for dev and production, which Okta groups should have access, and how groups map to roles. IT will provide `OKTA_CLIENT_ID`, `OKTA_ISSUER`, and the JWKS URI. Add these to your `.env` locally and your Doppler project for production.

### 7. Why does CI run the same checks as the pre-commit hooks?

Redundancy is intentional — this is defense in depth. Pre-commit hooks catch issues before they enter git, giving you fast feedback. But hooks can be skipped (`--no-verify`), misconfigured, or not installed on a new machine. CI runs on GitHub's infrastructure and cannot be bypassed. It also runs checks that are too slow for pre-commit (CodeQL analysis, full dependency audit, coverage gates). Think of pre-commit as the spell-checker in your editor and CI as the proofreader who reviews the final draft.

### 8. What happens if I accidentally commit a secret?

Act immediately: (1) Rotate the compromised credential — generate a new key/token and invalidate the old one. This is the most important step. (2) Remove the secret from the code and use an environment variable instead. (3) If you need to clean git history, use `git filter-repo` or BFG Repo-Cleaner (not `git filter-branch`). (4) Report it in `#application-security` on Slack so AppSec can assess the blast radius. Speed matters — automated scrapers monitor GitHub for leaked secrets and can exploit them within minutes.

### 9. I am building a quick prototype. Do I really need all of this?

Yes. Internal prototypes are the most common attack vector because they access real data and real systems but are built without security controls. "It is just a prototype" becomes "it is just an internal tool" becomes "it is production but we never added auth." This template is designed so the secure path is the easy path — `make setup` takes 30 seconds, and after that, security is automatic. You are not spending extra effort on security; you are spending zero effort because the template handles it.

### 10. Where do I go if I have security questions?

- **Slack:** `#application-security` — for questions, reviews, and incident reports
- **Pre-production review:** Before deploying any new service, post in `#application-security` with your service name, architecture summary, and the AppSec review checklist from CLAUDE.md
- **Vulnerability reports:** Follow the process in `SECURITY.md` — email, Slack, or PagerDuty depending on severity
- **This handbook:** You are reading it. It covers the fundamentals. For deeper reference, the CLAUDE.md file in the repo root contains the full rule set
- **OWASP:** [owasp.org/Top10](https://owasp.org/Top10/) for the source material behind Section 3
