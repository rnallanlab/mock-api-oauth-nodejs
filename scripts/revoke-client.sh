#!/bin/bash

# Client Revocation Script
# Usage: ./revoke-client.sh <client-name> <environment>
# Example: ./revoke-client.sh acme-corp dev

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

echo -e "${BLUE}=== Client Revocation Tool ===${NC}\n"
echo -e "Client Name: ${RED}${CLIENT_NAME}${NC}"
echo -e "Environment: ${RED}${ENVIRONMENT}${NC}\n"

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

# Check if client exists
if ! grep -q "\"${CLIENT_NAME}\"" "${TERRAFORM_DIR}/terraform.tfvars"; then
    echo -e "${RED}Error: Client '${CLIENT_NAME}' not found in terraform.tfvars${NC}"
    exit 1
fi

# Backup terraform.tfvars
BACKUP_FILE="${TERRAFORM_DIR}/terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${YELLOW}Step 1: Backing up terraform.tfvars...${NC}"
cp "${TERRAFORM_DIR}/terraform.tfvars" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: ${BACKUP_FILE}${NC}\n"

# Remove client from cognito_app_clients list
echo -e "${YELLOW}Step 2: Removing client from Cognito app clients...${NC}"
sed -i "" "/\"${CLIENT_NAME}\",/d" "${TERRAFORM_DIR}/terraform.tfvars"
echo -e "${GREEN}✓ Client removed from cognito_app_clients${NC}\n"

# Remove client from api_keys list
echo -e "${YELLOW}Step 3: Removing client from API keys...${NC}"
sed -i "" "/\"${CLIENT_NAME}\",/d" "${TERRAFORM_DIR}/terraform.tfvars"
echo -e "${GREEN}✓ Client removed from api_keys${NC}\n"

# Show diff
echo -e "${YELLOW}Step 4: Showing changes...${NC}"
diff -u "$BACKUP_FILE" "${TERRAFORM_DIR}/terraform.tfvars" || true
echo ""

# Warning
echo -e "${RED}⚠️  WARNING: This will revoke access for client '${CLIENT_NAME}'${NC}"
echo -e "${RED}    - Cognito App Client will be destroyed${NC}"
echo -e "${RED}    - API Key will be deleted${NC}"
echo -e "${RED}    - Client will lose access immediately after apply${NC}\n"

# Prompt for confirmation
read -p "Are you sure you want to revoke this client? (yes/no): " -r
echo ""

if [[ $REPLY == "yes" ]]; then
    echo -e "${YELLOW}Step 5: Apply Terraform changes${NC}"
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
        echo -e "${GREEN}✓ Client '${CLIENT_NAME}' has been revoked${NC}\n"
    else
        echo -e "\n${YELLOW}Skipping terraform apply.${NC}"
        echo -e "Changes have been made to: ${TERRAFORM_DIR}/terraform.tfvars"
        echo -e "Backup available at: ${BACKUP_FILE}"
        echo -e "\nTo apply manually, run:"
        echo -e "  cd ${TERRAFORM_DIR}"
        echo -e "  terraform plan"
        echo -e "  terraform apply"
    fi
else
    echo -e "\n${YELLOW}Revocation cancelled. Restoring backup...${NC}"
    mv "$BACKUP_FILE" "${TERRAFORM_DIR}/terraform.tfvars"
    echo -e "${GREEN}✓ terraform.tfvars restored${NC}\n"
fi

echo -e "${BLUE}=== Revocation Process Complete ===${NC}\n"
