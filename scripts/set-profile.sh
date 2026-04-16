#!/usr/bin/env bash
# === CW Secure Framework — Policy Profiles ===
# Sets enforcement level for the project.
# Usage: make profile LEVEL=balanced
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

LEVEL="${1:-}"

if [ -z "$LEVEL" ]; then
    echo ""
    echo -e "${BOLD}CW Secure Framework — Policy Profiles${NC}"
    echo ""
    echo "  Choose an enforcement level:"
    echo ""
    echo -e "  ${YELLOW}hackathon${NC}    Minimal friction. Secrets scanning only."
    echo "               Auth: DEV_MODE only. No coverage gate. No architecture enforcement."
    echo "               Best for: rapid prototyping, demos, hackathons."
    echo ""
    echo -e "  ${GREEN}balanced${NC}     Moderate enforcement. Secrets + architecture rules."
    echo "               Auth: DEV_MODE local, Okta in prod. 60% coverage gate."
    echo "               Best for: internal tools, team projects."
    echo ""
    echo -e "  ${BOLD}strict${NC}       Full enforcement (default). All rules active."
    echo "               Auth: Okta everywhere. 80% coverage gate. Full guard hooks."
    echo "               Best for: production services, compliance-required apps."
    echo ""
    echo -e "  ${RED}production${NC}   Maximum enforcement. Strict + audit logging + mTLS."
    echo "               Auth: Okta + mTLS. 90% coverage gate. Audit trail required."
    echo "               Best for: customer-facing services, SOC 2 compliance."
    echo ""
    echo "  Usage: make profile LEVEL=balanced"
    echo ""
    exit 0
fi

# Validate level
case "$LEVEL" in
    hackathon|balanced|strict|production) ;;
    *)
        echo -e "${RED}Unknown profile: $LEVEL${NC}"
        echo "  Valid profiles: hackathon, balanced, strict, production"
        exit 1
        ;;
esac

# Write profile file
echo "$LEVEL" > .profile

# Apply profile settings to .env
touch .env

set_env_var() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" .env 2>/dev/null; then
        sed -i '' "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

case "$LEVEL" in
    hackathon)
        set_env_var "DEV_MODE" "true"
        set_env_var "COVERAGE_THRESHOLD" "0"
        set_env_var "GUARD_LEVEL" "secrets"
        set_env_var "FORCE_PUSH_BLOCK" "false"
        set_env_var "AUDIT_LOGGING" "false"
        ;;
    balanced)
        set_env_var "DEV_MODE" "true"
        set_env_var "COVERAGE_THRESHOLD" "60"
        set_env_var "GUARD_LEVEL" "standard"
        set_env_var "FORCE_PUSH_BLOCK" "true"
        set_env_var "AUDIT_LOGGING" "false"
        ;;
    strict)
        set_env_var "DEV_MODE" "false"
        set_env_var "COVERAGE_THRESHOLD" "80"
        set_env_var "GUARD_LEVEL" "full"
        set_env_var "FORCE_PUSH_BLOCK" "true"
        set_env_var "AUDIT_LOGGING" "false"
        ;;
    production)
        set_env_var "DEV_MODE" "false"
        set_env_var "COVERAGE_THRESHOLD" "90"
        set_env_var "GUARD_LEVEL" "full"
        set_env_var "FORCE_PUSH_BLOCK" "true"
        set_env_var "AUDIT_LOGGING" "true"
        ;;
esac

echo ""
echo -e "${GREEN}Profile set to: ${BOLD}${LEVEL}${NC}"
echo ""

# Show what changed
case "$LEVEL" in
    hackathon)
        echo "  Auth:          DEV_MODE only (no Okta required)"
        echo "  Coverage:      off"
        echo "  Guard:         secrets scanning only"
        echo "  Force-push:    allowed"
        echo "  Audit logging: off"
        ;;
    balanced)
        echo "  Auth:          DEV_MODE local, Okta in production"
        echo "  Coverage:      60% minimum"
        echo "  Guard:         secrets + architecture enforcement"
        echo "  Force-push:    blocked"
        echo "  Audit logging: off"
        ;;
    strict)
        echo "  Auth:          Okta OIDC everywhere"
        echo "  Coverage:      80% minimum"
        echo "  Guard:         full enforcement"
        echo "  Force-push:    blocked"
        echo "  Audit logging: off"
        ;;
    production)
        echo "  Auth:          Okta OIDC + mTLS"
        echo "  Coverage:      90% minimum"
        echo "  Guard:         full enforcement + audit"
        echo "  Force-push:    blocked"
        echo "  Audit logging: on (all state changes logged)"
        ;;
esac

echo ""
echo "  Run ${BOLD}make doctor${NC} to verify the profile is applied correctly."
echo ""
