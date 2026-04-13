#!/usr/bin/env bash
# === CW Secure Template — Security Auto-Fix ===
# Runs security scanners, auto-fixes what's possible,
# prints human-readable guidance for everything else.
# Run: make fix
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

AUTO_FIXED=0
MANUAL_NEEDED=0

# ──────────────────────────────────────
# Tool check — tell user what's missing upfront
# ──────────────────────────────────────
MISSING_TOOLS=()
command -v gitleaks &>/dev/null || MISSING_TOOLS+=("gitleaks (brew install gitleaks)")
if [ -f go/go.mod ]; then
    command -v gosec &>/dev/null || MISSING_TOOLS+=("gosec (go install github.com/securego/gosec/v2/cmd/gosec@latest)")
    command -v govulncheck &>/dev/null || MISSING_TOOLS+=("govulncheck (go install golang.org/x/vuln/cmd/govulncheck@latest)")
fi
if [ -f python/pyproject.toml ]; then
    command -v bandit &>/dev/null || MISSING_TOOLS+=("bandit (pip install bandit)")
    command -v pip-audit &>/dev/null || MISSING_TOOLS+=("pip-audit (pip install pip-audit)")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}  Some security tools are not installed:${NC}"
    for tool in "${MISSING_TOOLS[@]}"; do
        echo -e "    - $tool"
    done
    echo ""
    echo -e "  Install them to get full security scanning."
    echo -e "  Continuing with what's available..."
fi

header() { echo -e "\n${BOLD}$1${NC}\n"; }
auto_fix() { echo -e "  ${GREEN}[AUTO-FIXED]${NC} $1"; ((AUTO_FIXED++)); }
manual() {
    ((MANUAL_NEEDED++))
    echo -e "  ${RED}[MANUAL FIX]${NC} $1"
    echo -e "    ${CYAN}Why:${NC} $2"
    echo -e "    ${CYAN}Fix:${NC} $3"
    echo ""
}

# ──────────────────────────────────────
header "1. Lint Auto-Fix"
# ──────────────────────────────────────

if [ -f go/go.mod ]; then
    echo "  Running golangci-lint --fix..."
    (cd go && golangci-lint run --fix 2>/dev/null) && auto_fix "Go lint issues"
fi

if [ -f python/pyproject.toml ]; then
    echo "  Running ruff --fix + format..."
    (cd python && ruff check --fix . 2>/dev/null && ruff format . 2>/dev/null) && auto_fix "Python lint + format issues"
fi

# ──────────────────────────────────────
header "2. Secret Scanning"
# ──────────────────────────────────────

if command -v gitleaks &>/dev/null; then
    LEAKS=$(gitleaks detect --source . --no-banner 2>&1)
    if [ $? -ne 0 ]; then
        echo "$LEAKS" | while IFS= read -r line; do
            if echo "$line" | grep -q "File:"; then
                FILE=$(echo "$line" | grep -oP 'File:\s*\K.*')
                manual "Secret detected in $FILE" \
                    "Hardcoded secrets can be extracted from git history even after deletion" \
                    "Remove the secret, use an env var instead, add to .env.example"
            fi
        done
    else
        echo -e "  ${GREEN}[CLEAN]${NC} No secrets detected"
    fi
else
    echo -e "  ${YELLOW}[SKIP]${NC} gitleaks not installed — run: brew install gitleaks"
fi

# ──────────────────────────────────────
header "3. Go Security Scan"
# ──────────────────────────────────────

if [ -f go/go.mod ]; then
    if command -v gosec &>/dev/null; then
        GOSEC_OUT=$(cd go && gosec -fmt=json ./... 2>/dev/null)
        ISSUE_COUNT=$(echo "$GOSEC_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Issues',[])))" 2>/dev/null || echo "0")
        if [ "$ISSUE_COUNT" -gt 0 ]; then
            echo "$GOSEC_OUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for issue in data.get('Issues', []):
    print(f\"  File: {issue['file']}:{issue['line']}\")
    print(f\"  Issue: {issue['details']}\")
    print(f\"  Severity: {issue['severity']}\")
    print()
" 2>/dev/null
        else
            echo -e "  ${GREEN}[CLEAN]${NC} No Go security issues"
        fi
    else
        echo -e "  ${YELLOW}[SKIP]${NC} gosec not installed — run: go install github.com/securego/gosec/v2/cmd/gosec@latest"
    fi

    # Vulnerability check
    if command -v govulncheck &>/dev/null; then
        echo "  Running govulncheck..."
        (cd go && govulncheck ./... 2>&1) | head -20
    fi
else
    echo -e "  ${YELLOW}[SKIP]${NC} No Go project found"
fi

# ──────────────────────────────────────
header "4. Python Security Scan"
# ──────────────────────────────────────

if [ -f python/pyproject.toml ]; then
    if command -v bandit &>/dev/null; then
        BANDIT_OUT=$(cd python && bandit -c bandit.yaml -r src/ -f json 2>/dev/null)
        BANDIT_COUNT=$(echo "$BANDIT_OUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('results',[])))" 2>/dev/null || echo "0")
        if [ "$BANDIT_COUNT" -gt 0 ]; then
            echo "$BANDIT_OUT" | python3 -c "
import sys, json
EXPLANATIONS = {
    'B101': ('assert used', 'Asserts are stripped in optimized mode (-O). Use proper validation.', 'Replace assert with if/raise'),
    'B105': ('hardcoded password', 'Passwords in code end up in git history forever.', 'Use os.environ[\"PASSWORD\"]'),
    'B106': ('hardcoded password in function arg', 'Same as B105 but in a function call.', 'Use os.environ'),
    'B301': ('pickle usage', 'Pickle can execute arbitrary code on deserialization.', 'Use json.loads() instead'),
    'B307': ('eval usage', 'eval() executes arbitrary code — remote code execution risk.', 'Use ast.literal_eval() or remove entirely'),
    'B506': ('yaml.load', 'yaml.load can execute arbitrary Python code.', 'Use yaml.safe_load()'),
    'B602': ('subprocess with shell=True', 'Shell injection risk with user input.', 'Use subprocess.run([\"cmd\", \"arg\"], shell=False)'),
    'B608': ('hardcoded SQL', 'SQL injection via string formatting.', 'Use parameterized queries: cursor.execute(\"SELECT ... WHERE id = %s\", (id,))'),
}
data = json.load(sys.stdin)
for r in data.get('results', []):
    code = r.get('test_id', '')
    exp = EXPLANATIONS.get(code, (r.get('test_name',''), r.get('issue_text',''), 'See bandit docs'))
    sev = r.get('issue_severity', 'MEDIUM')
    fname = r.get('filename', '?')
    line = r.get('line_number', '?')
    print(f'  [{sev}] {fname}:{line} — {exp[0]}')
    print(f'    Why: {exp[1]}')
    print(f'    Fix: {exp[2]}')
    print()
" 2>/dev/null
        else
            echo -e "  ${GREEN}[CLEAN]${NC} No Python security issues"
        fi
    else
        echo -e "  ${YELLOW}[SKIP]${NC} bandit not installed — run: pip install bandit"
    fi

    # Dependency audit
    if command -v pip-audit &>/dev/null; then
        echo "  Running pip-audit..."
        (cd python && pip-audit . 2>&1) | head -20
    fi
else
    echo -e "  ${YELLOW}[SKIP]${NC} No Python project found"
fi

# ──────────────────────────────────────
header "5. Dangerous Pattern Scan"
# ──────────────────────────────────────

# Check for common dangerous patterns
PATTERNS=(
    "eval(:.py:eval() executes arbitrary code:Remove eval or use ast.literal_eval()"
    "exec(:.py:exec() executes arbitrary code:Remove exec entirely"
    "pickle.loads:.py:Pickle deserialization runs arbitrary code:Use json.loads() instead"
    "os.system:.py:Shell command injection risk:Use subprocess.run() with a list"
    "yaml.load(:.py:yaml.load runs arbitrary code:Use yaml.safe_load()"
    "InsecureSkipVerify.*true:.go:Disables TLS verification:Remove or gate behind DISABLE_TLS_VERIFY env var"
    "template.HTML:.go:Marks string as safe HTML (XSS risk):Sanitize input before marking as HTML"
)

FOUND_DANGEROUS=0
for entry in "${PATTERNS[@]}"; do
    IFS=':' read -r pattern ext why fix <<< "$entry"
    HITS=$(grep -rn --include="*$ext" "$pattern" go/ python/ 2>/dev/null | grep -v "_test\." | grep -v "# SECURITY" | grep -v "// SECURITY")
    if [ -n "$HITS" ]; then
        echo "$HITS" | while IFS= read -r line; do
            manual "$line" "$why" "$fix"
        done
        ((FOUND_DANGEROUS++))
    fi
done

if [ "$FOUND_DANGEROUS" -eq 0 ]; then
    echo -e "  ${GREEN}[CLEAN]${NC} No dangerous patterns found"
fi

# ──────────────────────────────────────
# Summary
# ──────────────────────────────────────

echo ""
echo "============================================"
echo -e "${BOLD}Summary${NC}"
echo -e "  ${GREEN}Auto-fixed:${NC} $AUTO_FIXED issues"
echo -e "  ${RED}Manual fix needed:${NC} $MANUAL_NEEDED issues"

if [ "$MANUAL_NEEDED" -gt 0 ]; then
    echo ""
    echo -e "  Run ${CYAN}make doctor${NC} after fixing to verify."
    echo -e "  See ${CYAN}docs/security-handbook.md${NC} for explanations."
fi
echo ""
