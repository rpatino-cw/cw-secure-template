#!/usr/bin/env bash
# === CW Secure Framework — Doctor ===
# Comprehensive health check for the security pipeline.
# Run: make doctor
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local result="$2"  # 0=pass, 1=fail, 2=warn
    local msg="$3"

    if [ "$result" -eq 0 ]; then
        echo -e "  ${GREEN}[PASS]${NC} $name"
        ((PASS++))
    elif [ "$result" -eq 2 ]; then
        echo -e "  ${YELLOW}[WARN]${NC} $name — $msg"
        ((WARN++))
    else
        echo -e "  ${RED}[FAIL]${NC} $name — $msg"
        ((FAIL++))
    fi
}

echo ""
echo -e "${BOLD}CW Secure Framework — Security Health Check${NC}"
echo "============================================"

# ── Framework Info ──
ACTIVE_BLUEPRINT="none"
ACTIVE_STACK="unknown"
ACTIVE_PROFILE="strict"
[ -f .blueprint ] && ACTIVE_BLUEPRINT=$(cat .blueprint)
[ -f .stack ] && ACTIVE_STACK=$(cat .stack)
[ -f .profile ] && ACTIVE_PROFILE=$(cat .profile)
echo ""
echo -e "  Blueprint: ${BOLD}${ACTIVE_BLUEPRINT}${NC}  |  Stack: ${BOLD}${ACTIVE_STACK}${NC}  |  Profile: ${BOLD}${ACTIVE_PROFILE}${NC}"
echo ""

# ── Tools ──
echo -e "${BOLD}Tools${NC}"

command -v git &>/dev/null
check "git installed" $? "Install git"

command -v pre-commit &>/dev/null
check "pre-commit installed" $? "Run: pip install pre-commit"

command -v gitleaks &>/dev/null
check "gitleaks installed" $? "Run: brew install gitleaks"

if [ -f go/go.mod ]; then
    command -v go &>/dev/null
    check "go installed" $? "Install Go from go.dev"

    command -v golangci-lint &>/dev/null
    check "golangci-lint installed" $? "Run: brew install golangci-lint"

    go install golang.org/x/vuln/cmd/govulncheck@latest 2>/dev/null
    command -v govulncheck &>/dev/null
    check "govulncheck installed" $? "Run: go install golang.org/x/vuln/cmd/govulncheck@latest"
fi

if [ -f python/pyproject.toml ]; then
    command -v python3 &>/dev/null
    check "python3 installed" $? "Install Python 3.11+"

    command -v ruff &>/dev/null
    check "ruff installed" $? "Run: pip install ruff"

    command -v bandit &>/dev/null
    check "bandit installed" $? "Run: pip install bandit"
fi

# ── Git Hooks ──
echo ""
echo -e "${BOLD}Git Hooks${NC}"

if [ -d .git ]; then
    if [ -f .git/hooks/pre-commit ]; then
        check "pre-commit hook installed" 0 ""
    else
        check "pre-commit hook installed" 1 "Run: make setup"
    fi

    if [ -f .git/hooks/post-checkout ]; then
        check "post-checkout hook installed" 0 ""
    else
        check "post-checkout hook installed" 2 "Run: make setup"
    fi
else
    check "git repo initialized" 1 "Run: git init && make setup"
fi

# ── Config Files ──
echo ""
echo -e "${BOLD}Configuration${NC}"

[ -f .pre-commit-config.yaml ]
check ".pre-commit-config.yaml exists" $? "Missing — security hooks won't run"

[ -f CLAUDE.md ]
check "CLAUDE.md exists" $? "Missing — AI has no security guardrails"

[ -f .gitignore ]
check ".gitignore exists" $? "Missing — secrets could be committed"

[ -f .github/workflows/ci.yml ]
check "CI workflow exists" $? "Missing — no automated security checks"

[ -f .github/pull_request_template.md ]
check "PR template exists" $? "Missing — no security checklist on PRs"

# ── Environment ──
echo ""
echo -e "${BOLD}Environment${NC}"

if [ -f .env ]; then
    check ".env file exists" 0 ""

    # Check required vars are set (not empty)
    source .env 2>/dev/null
    if [ -n "${OKTA_ISSUER:-}" ]; then
        check "OKTA_ISSUER configured" 0 ""
    else
        check "OKTA_ISSUER configured" 2 "Auth will use DEV_MODE fallback"
    fi

    if [ -n "${OKTA_CLIENT_ID:-}" ]; then
        check "OKTA_CLIENT_ID configured" 0 ""
    else
        check "OKTA_CLIENT_ID configured" 2 "Auth will use DEV_MODE fallback"
    fi
else
    check ".env file exists" 1 "Run: cp .env.example .env && edit .env"
fi

# ── Code Quality ──
echo ""
echo -e "${BOLD}Code Quality${NC}"

# Check for hardcoded secrets patterns
SECRET_HITS=$(grep -rn --include="*.go" --include="*.py" -E "(password|secret|token|api_key)\s*[:=]\s*[\"'][^\"']{8,}" go/ python/ 2>/dev/null | grep -v "_test\." | grep -v ".example" | wc -l | tr -d ' ')
if [ "$SECRET_HITS" -eq 0 ]; then
    check "No hardcoded secrets in source" 0 ""
else
    check "No hardcoded secrets in source" 1 "Found $SECRET_HITS potential secrets — run: make security-scan"
fi

# Check for SECURITY TODO markers
SECURITY_TODOS=$(grep -rn "TODO.*SECURITY\|SECURITY.*TODO\|FIXME.*security\|security.*FIXME" go/ python/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$SECURITY_TODOS" -eq 0 ]; then
    check "No outstanding SECURITY TODOs" 0 ""
else
    check "No outstanding SECURITY TODOs" 2 "$SECURITY_TODOS items need attention"
fi

# Check for dangerous function usage
DANGEROUS=$(grep -rn --include="*.py" -E "eval\(|exec\(|pickle\.loads|os\.system\(|yaml\.load\(" python/src/ 2>/dev/null | wc -l | tr -d ' ')
if [ "$DANGEROUS" -eq 0 ]; then
    check "No dangerous Python functions in source" 0 ""
else
    check "No dangerous Python functions in source" 1 "Found $DANGEROUS dangerous calls — run: make security-scan"
fi

DANGEROUS_GO=$(grep -rn --include="*.go" -E 'InsecureSkipVerify:\s*true|template\.HTML\(' go/ 2>/dev/null | grep -v "_test\." | wc -l | tr -d ' ')
if [ "$DANGEROUS_GO" -eq 0 ]; then
    check "No dangerous Go patterns in source" 0 ""
else
    check "No dangerous Go patterns in source" 1 "Found $DANGEROUS_GO dangerous patterns — run: make security-scan"
fi

# ── .gitignore Coverage ──
echo ""
echo -e "${BOLD}.gitignore Coverage${NC}"

for pattern in ".env" "*.pem" "*.key" "credentials.json" "*.db"; do
    if grep -q "$pattern" .gitignore 2>/dev/null; then
        check ".gitignore blocks $pattern" 0 ""
    else
        check ".gitignore blocks $pattern" 1 "Add $pattern to .gitignore"
    fi
done

# ── Dropped Secrets ──
echo ""
echo -e "${BOLD}Dropped Secrets Scan${NC}"

if bash scripts/scan-drops.sh 2>/dev/null | grep -q "FOUND"; then
    check "No sensitive files in project root" 1 "Run: make add-config to store them safely"
else
    check "No sensitive files in project root" 0 ""
fi

# ── Architecture Compliance ──
echo ""
echo -e "${BOLD}Architecture Compliance${NC}"

# Check dependency direction violations (routes importing repositories directly)
if [ -d python/src/routes ]; then
    ROUTE_REPO_IMPORTS=$(grep -rn "from.*repositories\|import.*repositories" python/src/routes/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$ROUTE_REPO_IMPORTS" -eq 0 ]; then
        check "Routes don't import repositories directly" 0 ""
    else
        check "Routes don't import repositories directly" 1 "Routes must call services, not repositories. Fix: move DB logic to services/"
    fi
fi

if [ -d go/routes ] || [ -d go/handlers ]; then
    GO_ROUTE_REPO=$(grep -rn --include="*.go" '".*repositories\|repositories\.' go/routes/ go/handlers/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GO_ROUTE_REPO" -eq 0 ]; then
        check "Go handlers don't import repositories directly" 0 ""
    else
        check "Go handlers don't import repositories directly" 1 "Handlers must call services, not repositories. Fix: move DB logic to services/"
    fi
fi

# Check for inline route definitions in entry point
if [ -f python/src/main.py ]; then
    INLINE_ROUTES=$(grep -c "@app\.\(get\|post\|put\|delete\|patch\)" python/src/main.py 2>/dev/null || echo "0")
    if [ "$INLINE_ROUTES" -le 1 ]; then
        check "No inline routes in main.py (healthz exempt)" 0 ""
    else
        check "No inline routes in main.py" 2 "$INLINE_ROUTES routes inline — move to routes/ directory"
    fi
fi

# Check middleware presence
if [ -f python/src/main.py ]; then
    if grep -q "AuthMiddleware\|RequireAuth\|get_current_user" python/src/main.py 2>/dev/null; then
        check "Auth middleware wired" 0 ""
    else
        check "Auth middleware wired" 1 "Add auth middleware to main.py — Run: see .claude/rules/security.md"
    fi
    if grep -q "RateLimitMiddleware\|ratelimit" python/src/main.py 2>/dev/null; then
        check "Rate limiting wired" 0 ""
    else
        check "Rate limiting wired" 1 "Add rate limit middleware — every API needs rate limiting"
    fi
fi

if [ -f go/main.go ]; then
    if grep -q "auth\.\|Auth\|requireAuth" go/main.go 2>/dev/null; then
        check "Auth middleware wired" 0 ""
    else
        check "Auth middleware wired" 1 "Add auth middleware to main.go — see middleware/auth.go"
    fi
    if grep -q "ratelimit\.\|RateLimit" go/main.go 2>/dev/null; then
        check "Rate limiting wired" 0 ""
    else
        check "Rate limiting wired" 1 "Add rate limit middleware — see middleware/ratelimit.go"
    fi
fi

# ── Profile Compliance ──
echo ""
echo -e "${BOLD}Profile: ${ACTIVE_PROFILE}${NC}"

# Load env vars for profile checks
[ -f .env ] && source .env 2>/dev/null

COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
GUARD_LEVEL="${GUARD_LEVEL:-full}"

check "Profile file exists" 0 ""
echo -e "  Coverage threshold: ${BOLD}${COVERAGE_THRESHOLD}%${NC}  |  Guard level: ${BOLD}${GUARD_LEVEL}${NC}"

# ── Release Readiness ──
echo ""
echo -e "${BOLD}Release Readiness${NC}"

if [ -f LICENSE ]; then
    check "LICENSE file present" 0 ""
else
    check "LICENSE file present" 2 "Add a LICENSE file for open-source or internal compliance"
fi

if [ -f SECURITY.md ]; then
    check "SECURITY.md (incident response) present" 0 ""
else
    check "SECURITY.md present" 1 "Add incident response template — run: make setup"
fi

if [ -f CHANGELOG.md ]; then
    check "CHANGELOG.md present" 0 ""
else
    check "CHANGELOG.md present" 2 "Add a changelog to track releases"
fi

if [ -d .github/workflows ] && [ -f .github/workflows/ci.yml ]; then
    check "CI pipeline configured" 0 ""
else
    check "CI pipeline configured" 1 "No CI workflow — security checks won't run on PRs"
fi

# ── Summary ──
TOTAL=$((PASS + FAIL + WARN))
echo ""
echo "============================================"
echo -e "${BOLD}Security Posture: ${PASS}/${TOTAL} checks passing${NC}"
if [ "$FAIL" -gt 0 ]; then
    echo -e "${RED}${FAIL} critical issues need fixing${NC}"
fi
if [ "$WARN" -gt 0 ]; then
    echo -e "${YELLOW}${WARN} warnings to review${NC}"
fi
if [ "$FAIL" -eq 0 ] && [ "$WARN" -eq 0 ]; then
    echo -e "${GREEN}All checks passing. Pipeline is healthy.${NC}"
fi
echo ""

exit "$FAIL"
