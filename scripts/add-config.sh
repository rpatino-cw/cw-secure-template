#!/usr/bin/env bash
# === CW Secure Template — Secure Config Drop ===
# Safely stores config files (service accounts, kubeconfig, certs, etc.)
# in a gitignored secrets/ directory instead of the project root.
#
# Usage: make add-config
#
# WHY THIS EXISTS:
# People download config files (service-account.json, kubeconfig, .pem)
# and drop them in the project folder. These get committed to git.
# This script gives them a safe drop zone that's gitignored.
set -uo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Create secure directory
SECRETS_DIR=".secrets"
mkdir -p "$SECRETS_DIR"

# Ensure it's gitignored
if ! grep -q "^${SECRETS_DIR}/" .gitignore 2>/dev/null; then
  echo "${SECRETS_DIR}/" >> .gitignore
  echo -e "  ${DIM}Added ${SECRETS_DIR}/ to .gitignore${NC}"
fi

echo ""
echo -e "${BOLD}  Add a Config File${NC}"
echo "  ──────────────────"
echo ""
echo "  This stores sensitive files in .secrets/ (which is gitignored)."
echo "  Your code reads from .secrets/ instead of the project root."
echo ""
echo "  Common files people drop here:"
echo "    - service-account.json (GCP)"
echo "    - kubeconfig.yaml (Kubernetes)"
echo "    - *.pem, *.key (certificates)"
echo "    - credentials.json (OAuth)"
echo ""

# Get file path
read -rp "  Path to the file (drag & drop works): " FILE_PATH

# Clean up path (remove quotes from drag & drop)
FILE_PATH="${FILE_PATH//\'/}"
FILE_PATH="${FILE_PATH//\"/}"
FILE_PATH="${FILE_PATH## }"
FILE_PATH="${FILE_PATH%% }"

if [ ! -f "$FILE_PATH" ]; then
  echo -e "  ${RED}File not found: ${FILE_PATH}${NC}"
  exit 1
fi

FILENAME=$(basename "$FILE_PATH")

# Warn about specific dangerous files
case "$FILENAME" in
  *.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*)
    echo -e "  ${YELLOW}This looks like a private key or certificate.${NC}"
    echo "  It will be stored in .secrets/ and gitignored."
    ;;
  *service-account*|*credentials*|*kubeconfig*)
    echo -e "  ${YELLOW}This looks like a cloud credential file.${NC}"
    echo "  It will be stored in .secrets/ and gitignored."
    ;;
esac

# Check if already exists
if [ -f "${SECRETS_DIR}/${FILENAME}" ]; then
  echo ""
  echo -e "  ${YELLOW}${FILENAME} already exists in .secrets/.${NC}"
  read -rp "  Overwrite? [y/N]: " OVERWRITE
  if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
    echo "  Cancelled."
    exit 0
  fi
fi

# Copy to secrets directory
cp "$FILE_PATH" "${SECRETS_DIR}/${FILENAME}"

# Suggest env var for the path
VAR_NAME=$(echo "${FILENAME%%.*}" | tr '[:lower:]-' '[:upper:]_')_PATH

echo ""
echo -e "  ${GREEN}Done.${NC} ${FILENAME} is stored in .secrets/${FILENAME}"
echo ""
echo "  Use it in your code:"
echo -e "  ${DIM}  Python: Path(os.environ.get(\"${VAR_NAME}\", \".secrets/${FILENAME}\"))${NC}"
echo -e "  ${DIM}  Go:     os.Getenv(\"${VAR_NAME}\") // defaults to .secrets/${FILENAME}${NC}"
echo ""
echo -e "  ${YELLOW}Do you still have the original file somewhere else?${NC}"
echo "  If it was in your Downloads or Desktop, consider deleting it."
echo ""
echo -e "  ${RED}Never put config files in the project root.${NC}"
echo -e "  ${RED}Always use: make add-config${NC}"
echo ""
