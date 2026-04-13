#!/usr/bin/env bash
set -euo pipefail

# === CW Secure Template V2 — One-Command Setup ===
# Usage: bash setup.sh

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${BOLD}  CW Secure Template — Setup${NC}"
echo "  =============================="
echo ""

# --- Pick language ---
echo "Which language are you using?"
echo "  1) Go"
echo "  2) Python"
echo "  3) Both (keep both starters)"
echo ""
read -rp "Enter 1, 2, or 3: " lang_choice

case "$lang_choice" in
  1)
    echo "Removing Python starter..."
    rm -rf python/
    echo -e "${GREEN}Go project ready.${NC}"
    ;;
  2)
    echo "Removing Go starter..."
    rm -rf go/
    echo -e "${GREEN}Python project ready.${NC}"
    ;;
  3)
    echo "Keeping both starters."
    ;;
  *)
    echo "Invalid choice. Keeping both."
    ;;
esac

# --- Create .env ---
if [ ! -f .env ]; then
  cp .env.example .env
  echo ""
  echo -e "${GREEN}Created .env from .env.example${NC}"
  echo -e "${YELLOW}IMPORTANT: Edit .env with your Okta credentials before deploying.${NC}"
  echo "  For local dev, DEV_MODE=true bypasses auth with a test user."
else
  echo ".env already exists, skipping."
fi

# --- Init git if needed ---
if [ ! -d .git ]; then
  echo ""
  echo "Initializing git repo..."
  git init
fi

# --- Install pre-commit ---
echo ""
echo "Installing pre-commit hooks..."
if command -v pre-commit &> /dev/null; then
  pre-commit install
  echo -e "${GREEN}Pre-commit hooks installed.${NC}"
else
  echo -e "${YELLOW}pre-commit not found. Installing...${NC}"
  pip install pre-commit 2>/dev/null || brew install pre-commit 2>/dev/null
  pre-commit install
fi

# --- Install custom git hooks ---
echo "Installing security enforcement hooks..."
cp scripts/git-hooks/pre-commit .git/hooks/pre-commit 2>/dev/null || true
cp scripts/git-hooks/post-checkout .git/hooks/post-checkout 2>/dev/null || true
cp scripts/git-hooks/pre-push .git/hooks/pre-push 2>/dev/null || true
chmod +x .git/hooks/pre-commit .git/hooks/post-checkout .git/hooks/pre-push 2>/dev/null || true
echo -e "${GREEN}Git hooks installed.${NC}"

# --- Install language deps ---
if [ -f go/go.mod ]; then
  echo ""
  echo "Installing Go dependencies..."
  (cd go && go mod download 2>/dev/null) || echo -e "${YELLOW}Go not installed — install from go.dev${NC}"
fi

if [ -f python/pyproject.toml ]; then
  echo ""
  echo "Installing Python dependencies..."
  (cd python && pip install -e ".[dev]" 2>/dev/null) || echo -e "${YELLOW}pip install failed — check Python version (3.11+ required)${NC}"
fi

# --- Initial commit if fresh repo ---
if [ -z "$(git log --oneline -1 2>/dev/null)" ]; then
  git add .
  git commit -m "Initial commit from cw-secure-template"
  echo -e "${GREEN}Git repo initialized with initial commit.${NC}"
fi

# --- Auto-configure branch protection if gh CLI available ---
if command -v gh &>/dev/null; then
  REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
  if [ -n "$REPO" ]; then
    echo ""
    echo -e "${YELLOW}Configuring branch protection on main...${NC}"
    gh api -X PUT "repos/${REPO}/branches/main/protection" \
      --input - <<'PROTECTION' 2>/dev/null && echo -e "${GREEN}Branch protection configured.${NC}" || echo -e "${YELLOW}Branch protection skipped (may need admin access).${NC}"
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Secret Scanning", "Go Checks", "Python Checks", "Dependency Audit", "Hook Integrity Check"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
PROTECTION
  else
    echo -e "${YELLOW}No GitHub remote detected — skip branch protection. Run 'gh repo create' first.${NC}"
  fi
else
  echo -e "${YELLOW}gh CLI not installed — branch protection must be configured manually.${NC}"
  echo "  Install: brew install gh && gh auth login"
  echo "  Then run: gh workflow run branch-protection-setup.yml"
fi

# --- Health check ---
echo ""
echo "Running health check..."
bash scripts/doctor.sh || true

# --- Summary ---
echo ""
echo -e "${BOLD}  Setup complete!${NC}"
echo "  =============================="
echo ""
echo "  Quick start:"
echo "    make run            — Start the app"
echo "    make test           — Run tests"
echo "    make check          — Run all checks (before PRs)"
echo "    make fix            — Auto-fix issues"
echo "    make doctor         — Health check"
echo "    make learn          — Security quiz"
echo "    make dashboard      — Open security dashboard"
echo ""
echo "  Start building! Claude follows the security rules in CLAUDE.md."
echo ""
