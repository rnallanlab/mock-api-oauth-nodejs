#!/bin/bash

# Client Provisioning Script
# Usage: ./provision-client.sh <client-name> <environment>
# Example: ./provision-client.sh acme-corp dev

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Missing arguments${NC}"
    echo "Usage: $0 <client-name> <environment>"
    echo "Example: $0 acme-corp dev"
    exit 1
fi

CLIENT_NAME=$1
ENVIRONMENT=$2
TERRAFORM_DIR="../terraform/environments/${ENVIRONMENT}"

echo -e "${BLUE}=== Client Provisioning Tool ===${NC}\n"
echo -e "Client Name: ${GREEN}${CLIENT_NAME}${NC}"
echo -e "Environment: ${GREEN}${ENVIRONMENT}${NC}\n"

# Validate client name format
if ! [[ "$CLIENT_NAME" =~ ^[a-z0-9-]+$ ]]; then
    echo -e "${RED}Error: Client name must contain only lowercase letters, numbers, and hyphens${NC}"
    exit 1
fi

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${RED}Error: Terraform directory not found: ${TERRAFORM_DIR}${NC}"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found in ${TERRAFORM_DIR}${NC}"
    exit 1
fi

# Backup terraform.tfvars
BACKUP_FILE="${TERRAFORM_DIR}/terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}Step 1: Backing up terraform.tfvars...${NC}"
cp "${TERRAFORM_DIR}/terraform.tfvars" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: ${BACKUP_FILE}${NC}\n"

# Check if client already exists
if grep -q "\"${CLIENT_NAME}\"" "${TERRAFORM_DIR}/terraform.tfvars"; then
    echo -e "${RED}Error: Client '${CLIENT_NAME}' already exists in terraform.tfvars${NC}"
    echo -e "Remove backup if not needed: ${BACKUP_FILE}"
    exit 1
fi

# Add client to cognito_app_clients list
echo -e "${YELLOW}Step 2: Adding client to Cognito app clients...${NC}"

# Find the cognito_app_clients line and add the new client
awk -v client="$CLIENT_NAME" '
/^cognito_app_clients = \[/ {
    print $0
    # Read all lines until we find the closing bracket
    while (getline > 0) {
        if ($0 ~ /^\]/) {
            # Found closing bracket, add new client before it
            print "  \"" client "\","
            print $0
            break
        } else {
            print $0
        }
    }
    next
}
{ print }
' "${TERRAFORM_DIR}/terraform.tfvars" > "${TERRAFORM_DIR}/terraform.tfvars.tmp"

mv "${TERRAFORM_DIR}/terraform.tfvars.tmp" "${TERRAFORM_DIR}/terraform.tfvars"
echo -e "${GREEN}✓ Client added to cognito_app_clients${NC}\n"

# Add client to api_keys list
echo -e "${YELLOW}Step 3: Adding client to API keys...${NC}"

awk -v client="$CLIENT_NAME" '
/^api_keys = \[/ {
    print $0
    # Read all lines until we find the closing bracket
    while (getline > 0) {
        if ($0 ~ /^\]/) {
            # Found closing bracket, add new client before it
            print "  \"" client "\","
            print $0
            break
        } else {
            print $0
        }
    }
    next
}
{ print }
' "${TERRAFORM_DIR}/terraform.tfvars" > "${TERRAFORM_DIR}/terraform.tfvars.tmp"

mv "${TERRAFORM_DIR}/terraform.tfvars.tmp" "${TERRAFORM_DIR}/terraform.tfvars"
echo -e "${GREEN}✓ Client added to api_keys${NC}\n"

# Show diff
echo -e "${YELLOW}Step 4: Showing changes...${NC}"
diff -u "$BACKUP_FILE" "${TERRAFORM_DIR}/terraform.tfvars" || true
echo ""

# Prompt for confirmation
echo -e "${YELLOW}Step 5: Apply Terraform changes?${NC}"
read -p "Do you want to run 'terraform apply' now? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd "$TERRAFORM_DIR"

    echo -e "\n${YELLOW}Running terraform init...${NC}"
    terraform init

    echo -e "\n${YELLOW}Running terraform plan...${NC}"
    terraform plan -out=tfplan

    echo -e "\n${YELLOW}Running terraform apply...${NC}"
    terraform apply tfplan

    echo -e "\n${GREEN}✓ Terraform apply completed${NC}\n"

    # Get client credentials
    echo -e "${BLUE}=== Client Credentials ===${NC}\n"

    COGNITO_DOMAIN=$(terraform output -raw cognito_user_pool_domain 2>/dev/null || echo "N/A")
    CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null || echo "N/A")
    CLIENT_SECRET=$(terraform output -raw cognito_client_secret 2>/dev/null || echo "N/A")
    API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "N/A")
    API_KEY=$(terraform output -json api_key_values 2>/dev/null | jq -r ".\"${CLIENT_NAME}\"" || echo "N/A")

    echo -e "Client Name:      ${GREEN}${CLIENT_NAME}${NC}"
    echo -e "Environment:      ${GREEN}${ENVIRONMENT}${NC}"
    echo -e "COGNITO_DOMAIN:   ${GREEN}${COGNITO_DOMAIN}${NC}"
    echo -e "CLIENT_ID:        ${GREEN}${CLIENT_ID}${NC}"
    echo -e "CLIENT_SECRET:    ${GREEN}${CLIENT_SECRET}${NC}"
    echo -e "API_ENDPOINT:     ${GREEN}${API_ENDPOINT}${NC}"
    echo -e "API_KEY:          ${GREEN}${API_KEY}${NC}"
    echo -e "REGION:           ${GREEN}us-east-1${NC}"

    # Save credentials to file
    CREDS_FILE="../client-credentials/${CLIENT_NAME}-${ENVIRONMENT}-$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p ../client-credentials

    cat > "$CREDS_FILE" << EOF
# Client Credentials for ${CLIENT_NAME} (${ENVIRONMENT})
# Generated: $(date)
# IMPORTANT: Store these credentials securely and delete this file after use

export COGNITO_DOMAIN="${COGNITO_DOMAIN}"
export CLIENT_ID="${CLIENT_ID}"
export CLIENT_SECRET="${CLIENT_SECRET}"
export REGION="us-east-1"
export API_ENDPOINT="${API_ENDPOINT}"
export API_KEY="${API_KEY}"
EOF

    echo -e "\n${GREEN}✓ Credentials saved to: ${CREDS_FILE}${NC}"
    echo -e "${YELLOW}⚠️  Remember to securely share these credentials and delete the file${NC}\n"

else
    echo -e "\n${YELLOW}Skipping terraform apply.${NC}"
    echo -e "Changes have been made to: ${TERRAFORM_DIR}/terraform.tfvars"
    echo -e "Backup available at: ${BACKUP_FILE}"
    echo -e "\nTo apply manually, run:"
    echo -e "  cd ${TERRAFORM_DIR}"
    echo -e "  terraform plan"
    echo -e "  terraform apply"
fi

echo -e "\n${BLUE}=== Provisioning Complete ===${NC}\n"
