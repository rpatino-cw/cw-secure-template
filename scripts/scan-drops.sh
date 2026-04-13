#!/usr/bin/env bash
# === CW Secure Template — Dropped Secrets Scanner ===
# Scans the project for sensitive files that were dropped in the wrong place.
# Run automatically during `make doctor` and `make check`.
set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

FOUND=0

check_pattern() {
  local pattern="$1"
  local desc="$2"
  local fix="$3"

  local files
  files=$(find . -name "$pattern" -not -path './.git/*' -not -path './.secrets/*' -not -path './.venv/*' -not -path './.archived/*' -not -path '*/egg-info/*' 2>/dev/null)

  if [ -n "$files" ]; then
    echo "$files" | while IFS= read -r f; do
      echo -e "  ${RED}FOUND${NC}  $f"
      echo -e "         ${DIM}$desc${NC}"
      echo -e "         Fix: ${YELLOW}$fix${NC}"
      echo ""
    done
    ((FOUND++)) || true
  fi
}

echo ""
echo -e "${BOLD}  Scanning for dropped secrets...${NC}"
echo ""

# Private keys
check_pattern "*.pem" "Private key — can grant access to servers and services" "make add-config"
check_pattern "*.key" "Private key file" "make add-config"
check_pattern "*.p12" "PKCS#12 certificate bundle (contains private key)" "make add-config"
check_pattern "*.pfx" "PFX certificate (contains private key)" "make add-config"
check_pattern "id_rsa" "SSH private key" "Delete from project, use ~/.ssh/"
check_pattern "id_ed25519" "SSH private key" "Delete from project, use ~/.ssh/"

# Cloud credentials
check_pattern "service-account*.json" "GCP service account key — full access to cloud resources" "make add-config"
check_pattern "credentials.json" "OAuth credentials — can impersonate your app" "make add-config"
check_pattern "kubeconfig*" "Kubernetes config — contains cluster access tokens" "make add-config"
check_pattern ".kube" "Kubernetes config directory" "Delete from project"

# Environment dumps
check_pattern "*.env.bak" "Environment backup — contains real secret values" "Delete it, secrets belong in .env only"
check_pattern "env.txt" "Environment dump — may contain secret values" "Delete it"
check_pattern "env.json" "Environment dump — may contain secret values" "Delete it"

# Debug dumps
check_pattern "*.har" "HTTP archive — contains auth headers and cookies" "Delete it"
check_pattern "curl-output*" "Curl debug output — may contain auth tokens" "Delete it"
check_pattern "response*.json" "API response dump — may contain tokens" "Check for secrets, delete if sensitive"

# Database files
check_pattern "*.sqlite" "SQLite database — may contain user data" "Add to .gitignore or move to .secrets/"
check_pattern "*.db" "Database file — may contain sensitive data" "Add to .gitignore or move to .secrets/"

# Terraform
check_pattern "*.tfstate" "Terraform state — contains infrastructure secrets" "Never commit, use remote state"
check_pattern "*.tfvars" "Terraform variables — may contain secrets" "make add-config"

# Cloud CLI configs
check_pattern ".aws" "AWS config directory — contains access keys" "Delete from project, use ~/.aws/"
check_pattern ".azure" "Azure config — contains credentials" "Delete from project"

if [ "$FOUND" -eq 0 ]; then
  echo -e "  ${GREEN}No dropped secrets found.${NC}"
fi

echo ""
exit "$FOUND"
