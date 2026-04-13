#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────
# OWASP Top 10 Security Quiz — 15 questions, Go & Python snippets
# Run via: make learn
# ──────────────────────────────────────────────────────────────────────

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
CYAN='\033[0;36m'
RESET='\033[0m'

SCORE=0
TOTAL=15
QUESTION_NUM=0

# ── Helper ────────────────────────────────────────────────────────────
# ask_question <question_text> <correct_letter> <explanation>
ask_question() {
  local question="$1"
  local correct="$2"
  local explanation="$3"

  QUESTION_NUM=$((QUESTION_NUM + 1))

  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${question}${RESET}"
  echo ""

  while true; do
    read -rp "Your answer (A/B/C/D): " answer
    answer=$(echo "$answer" | tr '[:lower:]' '[:upper:]')
    if [[ "$answer" =~ ^[ABCD]$ ]]; then
      break
    fi
    echo "  Please enter A, B, C, or D."
  done

  if [[ "$answer" == "$correct" ]]; then
    SCORE=$((SCORE + 1))
    echo -e "\n${GREEN}  Correct!${RESET}"
  else
    echo -e "\n${RED}  Wrong. The correct answer is ${correct}.${RESET}"
  fi

  echo -e "${YELLOW}  ${explanation}${RESET}"
}

# ── Intro ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║              OWASP Top 10 — Security Quiz (15 Questions)            ║${RESET}"
echo -e "${BOLD}${CYAN}║          Alternating Go and Python code snippets                    ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "Each question shows a code snippet and asks: What's wrong?"
echo "Answer A, B, C, or D. Let's go."

# ══════════════════════════════════════════════════════════════════════
# Q1 — SQL Injection (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q1: What's wrong with this Python code?

  cursor.execute(f\"SELECT * FROM users WHERE id = '{user_id}'\")

A) Nothing -- f-strings work fine for SQL
B) SQL injection -- user input directly in the query
C) Missing error handling
D) Should use SELECT columns, not SELECT *" \
  "B" \
  "B is correct: This is textbook SQL injection. The user_id is interpolated
  directly into the SQL string, letting an attacker inject arbitrary SQL.
  Fix: cursor.execute('SELECT * FROM users WHERE id = %s', (user_id,)).
  A is wrong: f-strings are fine for normal strings, but never for SQL queries.
  C is wrong: error handling is good practice but not a security vulnerability here.
  D is wrong: SELECT * is a performance/maintenance concern, not a security flaw."

# ══════════════════════════════════════════════════════════════════════
# Q2 — XSS (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q2: What's wrong with this Go HTTP handler?

  func handler(w http.ResponseWriter, r *http.Request) {
      name := r.URL.Query().Get(\"name\")
      fmt.Fprintf(w, \"<h1>Hello, %s</h1>\", name)
  }

A) Missing Content-Type header
B) Should use http.Error instead of Fprintf
C) Cross-site scripting (XSS) -- user input rendered as raw HTML
D) Missing CSRF token validation" \
  "C" \
  "C is correct: The 'name' query parameter is written directly into HTML
  without escaping. An attacker can inject <script> tags via the URL.
  Fix: use html/template or html.EscapeString(name).
  A is wrong: missing Content-Type may cause browser quirks but isn't the
  primary vulnerability here.
  B is wrong: http.Error is for error responses, not a security fix.
  D is wrong: CSRF matters for state-changing POST requests, not GET handlers
  that just display data."

# ══════════════════════════════════════════════════════════════════════
# Q3 — Hardcoded Secrets (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q3: What's wrong with this Python code?

  import boto3

  client = boto3.client(
      's3',
      aws_access_key_id='AKIAIOSFODNN7EXAMPLE',
      aws_secret_access_key='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
  )

A) Should use boto3.resource instead of boto3.client
B) Hardcoded credentials -- secrets should never be in source code
C) Missing region_name parameter
D) The S3 client should be initialized inside a function" \
  "B" \
  "B is correct: AWS keys are hardcoded in source. If this file is committed
  to git, anyone with repo access has your AWS credentials. Fix: use
  environment variables, AWS profiles, or a secrets manager.
  A is wrong: client vs resource is an API style choice, not a security issue.
  C is wrong: missing region is a config issue that causes runtime errors, not
  a security vulnerability.
  D is wrong: initialization location is a design pattern concern, not security."

# ══════════════════════════════════════════════════════════════════════
# Q4 — Shell Injection (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q4: What's wrong with this Go code?

  func ping(host string) ([]byte, error) {
      cmd := exec.Command(\"sh\", \"-c\", \"ping -c 1 \" + host)
      return cmd.CombinedOutput()
  }

A) Should use exec.Command(\"ping\", \"-c\", \"1\", host) instead
B) Missing timeout on the command
C) Shell injection -- user input passed to sh -c unsanitized
D) Both A and C -- A is the fix for the vulnerability in C" \
  "D" \
  "D is correct: C identifies the vulnerability (shell injection via sh -c
  with unsanitized input -- an attacker could pass '8.8.8.8; rm -rf /')
  and A is the fix (passing args directly to exec.Command bypasses the shell).
  A alone is incomplete: it describes the fix but doesn't name the vulnerability.
  C alone is incomplete: it names the problem but not the solution.
  B is wrong: timeouts prevent hangs but don't fix injection."

# ══════════════════════════════════════════════════════════════════════
# Q5 — Insecure Deserialization / Pickle (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q5: What's wrong with this Python code?

  import pickle

  def load_user_session(data: bytes):
      return pickle.loads(data)

A) Should use json.loads instead for better performance
B) Insecure deserialization -- pickle.loads can execute arbitrary code
C) Missing type validation on the return value
D) The data parameter should be a string, not bytes" \
  "B" \
  "B is correct: pickle.loads on untrusted data is remote code execution.
  An attacker can craft a pickle payload that runs os.system('...') when
  deserialized. Fix: use JSON, or if pickle is required, use hmac signing
  to verify the data hasn't been tampered with.
  A is wrong: JSON is safer but the reason isn't performance -- it's security.
  C is wrong: type validation helps but doesn't prevent the RCE in pickle.
  D is wrong: pickle.loads expects bytes, this signature is correct."

# ══════════════════════════════════════════════════════════════════════
# Q6 — CSRF / Missing Auth Check (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q6: What's wrong with this Go handler?

  func deleteAccount(w http.ResponseWriter, r *http.Request) {
      userID := r.URL.Query().Get(\"user_id\")
      db.Exec(\"DELETE FROM users WHERE id = ?\", userID)
      fmt.Fprint(w, \"Account deleted\")
  }

A) Should return JSON instead of plain text
B) Missing CSRF protection -- state-changing action via GET with no token
C) Should use soft-delete instead of hard-delete
D) Missing error handling on db.Exec" \
  "B" \
  "B is correct: A destructive action (DELETE) is triggered by a simple GET
  request with no CSRF token. An attacker can trick a logged-in user into
  clicking a link that deletes their account. Fix: require POST + CSRF token,
  or use SameSite cookies and verify Origin header.
  A is wrong: response format is an API design choice, not a security issue.
  C is wrong: soft vs hard delete is a data retention decision, not security.
  D is wrong: error handling is good practice but doesn't fix the CSRF flaw."

# ══════════════════════════════════════════════════════════════════════
# Q7 — eval/exec (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q7: What's wrong with this Python code?

  def calculate(expression: str) -> float:
      return eval(expression)

  # Called as: calculate(request.args['expr'])

A) eval() is slow -- use ast.literal_eval() for performance
B) Remote code execution -- eval() executes arbitrary Python code
C) Should validate that the result is a float before returning
D) Missing try/except for malformed expressions" \
  "B" \
  "B is correct: eval() on user input is remote code execution. An attacker
  can pass __import__('os').system('rm -rf /') as the expression. Fix: use
  ast.literal_eval() for safe literal parsing, or a math expression parser.
  A is wrong: ast.literal_eval is safer, not faster -- the reason to switch
  is security, not performance.
  C is wrong: type checking the result doesn't prevent the code execution.
  D is wrong: error handling won't stop malicious code from running inside eval."

# ══════════════════════════════════════════════════════════════════════
# Q8 — Missing Authentication (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q8: What's wrong with this Go API?

  func getUser(w http.ResponseWriter, r *http.Request) {
      id := mux.Vars(r)[\"id\"]
      user, _ := db.FindUser(id)
      json.NewEncoder(w).Encode(user)
  }

  // Route: GET /api/users/{id}

A) Missing authentication -- any caller can fetch any user's data
B) Should use query params instead of path params
C) Ignoring the error from db.FindUser
D) Both A and C -- broken access control and swallowed errors" \
  "D" \
  "D is correct: A identifies the main vulnerability (no auth check -- anyone
  can enumerate user records by ID, a classic broken access control flaw) and
  C catches the swallowed error (if FindUser fails, you encode a nil/zero user
  instead of returning 404). Both are real problems.
  A alone is incomplete: the swallowed error is also a real issue.
  B is wrong: path vs query params is a REST convention, not a security issue.
  C alone is incomplete: the auth gap is the more critical vulnerability."

# ══════════════════════════════════════════════════════════════════════
# Q9 — Missing Rate Limiting (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q9: What's wrong with this Python login endpoint?

  @app.route('/login', methods=['POST'])
  def login():
      username = request.form['username']
      password = request.form['password']
      user = User.query.filter_by(username=username).first()
      if user and check_password_hash(user.password_hash, password):
          session['user_id'] = user.id
          return redirect('/dashboard')
      return render_template('login.html', error='Invalid credentials')

A) Should use bcrypt instead of Werkzeug's check_password_hash
B) No rate limiting -- endpoint is vulnerable to brute-force attacks
C) Storing user_id in session is insecure
D) Should return 401 status code on failed login" \
  "B" \
  "B is correct: No rate limiting means an attacker can try millions of
  passwords. Fix: add per-IP and per-account rate limiting (e.g.,
  flask-limiter), account lockout after N failures, or CAPTCHA.
  A is wrong: Werkzeug's check_password_hash supports bcrypt and other
  secure algorithms -- it's not inherently weaker.
  C is wrong: server-side session storage of user_id is standard and safe
  when the session cookie is signed.
  D is wrong: returning 401 is good API design but doesn't stop brute-force."

# ══════════════════════════════════════════════════════════════════════
# Q10 — Exposed Debug Info (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q10: What's wrong with this Go error handler?

  func handleError(w http.ResponseWriter, err error) {
      w.WriteHeader(http.StatusInternalServerError)
      fmt.Fprintf(w, \"Error: %+v\\nStack: %s\", err, debug.Stack())
  }

A) Should use http.StatusBadRequest instead of 500
B) Security misconfiguration -- stack traces and error details exposed to users
C) Should log the error instead of ignoring it
D) Missing Content-Type header for the error response" \
  "B" \
  "B is correct: Sending full error messages and stack traces to the client
  reveals internal paths, library versions, and code structure that attackers
  use for reconnaissance. Fix: log the full error server-side, return a
  generic message to the client.
  A is wrong: the status code choice depends on the error type, not security.
  C is wrong: the code IS outputting the error (to the client) -- the problem
  is WHERE it goes, not that it's ignored.
  D is wrong: Content-Type is a good practice but not the vulnerability here."

# ══════════════════════════════════════════════════════════════════════
# Q11 — Dependency Vulnerabilities (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q11: What's wrong with this Python requirements.txt?

  flask==1.0.2
  requests==2.19.1
  pyyaml==3.13
  jinja2==2.10

A) Should use >= instead of == to get latest patches automatically
B) Vulnerable dependencies -- these are years-old versions with known CVEs
C) Missing version pins -- should lock to exact versions
D) Too many dependencies -- should reduce the dependency count" \
  "B" \
  "B is correct: These are severely outdated versions. pyyaml 3.13 has
  arbitrary code execution via yaml.load(), jinja2 2.10 has sandbox escapes,
  and the others have known CVEs. Fix: update to current versions, run
  'pip-audit' or 'safety check' in CI.
  A is wrong: >= pins can pull in breaking changes and don't guarantee
  security -- you need active dependency scanning.
  C is wrong: the versions ARE pinned (==) -- the problem is they're pinned
  to vulnerable versions.
  D is wrong: dependency count isn't the issue; outdated dependencies are."

# ══════════════════════════════════════════════════════════════════════
# Q12 — Path Traversal (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q12: What's wrong with this Go file server?

  func serveFile(w http.ResponseWriter, r *http.Request) {
      filename := r.URL.Query().Get(\"file\")
      data, err := os.ReadFile(\"/app/uploads/\" + filename)
      if err != nil {
          http.Error(w, \"Not found\", 404)
          return
      }
      w.Write(data)
  }

A) Should use http.ServeFile instead of manual file reading
B) Path traversal -- attacker can use ../../../etc/passwd to read any file
C) Missing Content-Type detection for the served file
D) Should check file extension against an allowlist" \
  "B" \
  "B is correct: An attacker can request ?file=../../../etc/passwd to escape
  the uploads directory and read arbitrary files on the server. Fix: use
  filepath.Clean(), verify the resolved path starts with /app/uploads/, or
  use http.FileServer with http.Dir (which blocks traversal).
  A is wrong: http.ServeFile also needs path validation -- it doesn't
  automatically prevent traversal on arbitrary input.
  C is wrong: Content-Type is a usability concern, not a security vulnerability.
  D is wrong: extension allowlists help but don't block ../../etc/passwd."

# ══════════════════════════════════════════════════════════════════════
# Q13 — Insecure Deserialization / YAML (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q13: What's wrong with this Python code?

  import yaml

  def load_config(user_upload: bytes):
      return yaml.load(user_upload, Loader=yaml.FullLoader)

A) Should use yaml.safe_load() instead of yaml.load() with FullLoader
B) FullLoader is the recommended safe loader -- this code is fine
C) Missing file encoding specification
D) Should validate the YAML schema after loading" \
  "A" \
  "A is correct: yaml.FullLoader can still instantiate arbitrary Python
  objects in some PyYAML versions. yaml.safe_load() (or Loader=yaml.SafeLoader)
  restricts deserialization to basic types only. On untrusted input, always
  use safe_load.
  B is wrong: FullLoader was introduced as a middle ground but is NOT safe
  for untrusted input -- it can still execute code in certain scenarios.
  C is wrong: encoding is a data handling concern, not a security vulnerability.
  D is wrong: schema validation is good practice but happens after loading --
  the exploit runs during deserialization, before validation."

# ══════════════════════════════════════════════════════════════════════
# Q14 — Logging Secrets (Go)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q14: What's wrong with this Go authentication middleware?

  func authMiddleware(next http.Handler) http.Handler {
      return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
          token := r.Header.Get(\"Authorization\")
          log.Printf(\"Auth attempt: token=%s, ip=%s, path=%s\",
              token, r.RemoteAddr, r.URL.Path)
          if !validateToken(token) {
              http.Error(w, \"Unauthorized\", 401)
              return
          }
          next.ServeHTTP(w, r)
      })
  }

A) Should use structured logging instead of Printf
B) Logging secrets -- auth tokens written to logs in plaintext
C) Should check token before logging the request
D) Missing rate limiting on auth failures" \
  "B" \
  "B is correct: The full auth token is logged in plaintext. Logs are often
  stored in centralized systems (ELK, Splunk, CloudWatch) accessible to many
  engineers. Anyone with log access can steal tokens. Fix: log a truncated
  hash or token ID, never the full token.
  A is wrong: structured logging is better for parsing but doesn't fix the
  secret exposure.
  C is wrong: checking the token first changes the order but doesn't prevent
  the token from being logged on valid requests.
  D is wrong: rate limiting is a separate concern -- the secret leak is the
  vulnerability."

# ══════════════════════════════════════════════════════════════════════
# Q15 — TLS Bypass (Python)
# ══════════════════════════════════════════════════════════════════════
ask_question "Q15: What's wrong with this Python code?

  import requests

  def fetch_payment_status(txn_id: str) -> dict:
      resp = requests.get(
          f'https://payments.internal.corp/api/status/{txn_id}',
          verify=False,
          timeout=10,
      )
      return resp.json()

A) Should use POST instead of GET for payment data
B) TLS verification disabled -- vulnerable to man-in-the-middle attacks
C) Missing authentication header for the payments API
D) The timeout is too long for an internal service call" \
  "B" \
  "B is correct: verify=False disables TLS certificate validation, meaning
  any attacker on the network can intercept and modify traffic between your
  service and the payments API (man-in-the-middle). This is especially
  dangerous for financial data. Fix: remove verify=False (defaults to True),
  or point verify= to your internal CA bundle.
  A is wrong: GET vs POST is an API design choice -- GET is fine for reading
  status if the endpoint is designed for it.
  C is wrong: missing auth is a valid concern but not what verify=False causes.
  D is wrong: 10s timeout is reasonable for most internal calls."

# ══════════════════════════════════════════════════════════════════════
# Results
# ══════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}  RESULTS: ${SCORE}/${TOTAL}${RESET}"
echo ""

if (( SCORE >= 13 )); then
  echo -e "${GREEN}${BOLD}  Rating: Security Expert${RESET}"
  echo -e "${GREEN}  You have a strong grasp of common web application vulnerabilities.${RESET}"
elif (( SCORE >= 10 )); then
  echo -e "${GREEN}  Rating: Solid Foundation${RESET}"
  echo "  Good awareness. Review the ones you missed and you're in great shape."
elif (( SCORE >= 7 )); then
  echo -e "${YELLOW}  Rating: Getting There${RESET}"
  echo "  You know the basics. Spend time with the OWASP Top 10 documentation."
else
  echo -e "${RED}  Rating: Needs Work${RESET}"
  echo "  Start with docs/security-handbook.md and the OWASP Top 10 cheat sheets."
fi

echo ""
echo -e "${CYAN}  Topics covered: SQL injection, XSS, hardcoded secrets, shell injection,${RESET}"
echo -e "${CYAN}  insecure deserialization (pickle + YAML), CSRF, missing auth, missing${RESET}"
echo -e "${CYAN}  rate limiting, exposed debug info, dependency vulns, path traversal,${RESET}"
echo -e "${CYAN}  logging secrets, TLS bypass, eval/exec.${RESET}"
echo ""
echo -e "${BOLD}  Learn more: https://owasp.org/www-project-top-ten/${RESET}"
echo ""
