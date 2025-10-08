#!/bin/bash

# List Clients Script
# Usage: ./list-clients.sh <environment>
# Example: ./list-clients.sh dev

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check arguments
if [ $# -lt 1 ]; then
    echo -e "${YELLOW}Usage: $0 <environment>${NC}"
    echo "Example: $0 dev"
    exit 1
fi

ENVIRONMENT=$1
TERRAFORM_DIR="../terraform/environments/${ENVIRONMENT}"

echo -e "${BLUE}=== Client List for ${ENVIRONMENT} Environment ===${NC}\n"

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo -e "${YELLOW}Error: Terraform directory not found: ${TERRAFORM_DIR}${NC}"
    exit 1
fi

# Check if terraform.tfvars exists
if [ ! -f "${TERRAFORM_DIR}/terraform.tfvars" ]; then
    echo -e "${YELLOW}Error: terraform.tfvars not found in ${TERRAFORM_DIR}${NC}"
    exit 1
fi

# Extract and display clients from cognito_app_clients
echo -e "${GREEN}Cognito App Clients:${NC}"
grep -A 100 "^cognito_app_clients = \[" "${TERRAFORM_DIR}/terraform.tfvars" | \
    grep -B 100 "^\]" | \
    grep "\"" | \
    sed 's/[",]//g' | \
    sed 's/^[ \t]*/  - /'

echo ""

# Extract and display clients from api_keys
echo -e "${GREEN}API Keys:${NC}"
grep -A 100 "^api_keys = \[" "${TERRAFORM_DIR}/terraform.tfvars" | \
    grep -B 100 "^\]" | \
    grep "\"" | \
    sed 's/[",]//g' | \
    sed 's/^[ \t]*/  - /'

echo ""

# Count clients
CLIENT_COUNT=$(grep -A 100 "^cognito_app_clients = \[" "${TERRAFORM_DIR}/terraform.tfvars" | \
    grep -B 100 "^\]" | \
    grep "\"" | \
    wc -l | \
    tr -d ' ')

echo -e "${BLUE}Total Clients: ${CLIENT_COUNT}${NC}\n"
