#!/bin/bash

# Manual Credential Rotation Script
# Usage: ./rotate-credentials.sh <client-name> <environment>
# Example: ./rotate-credentials.sh acme-corp dev

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

echo -e "${BLUE}=== Manual Credential Rotation ===${NC}\n"
echo -e "Client Name: ${YELLOW}${CLIENT_NAME}${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}\n"

# Warning
echo -e "${RED}⚠️  WARNING: Manual Credential Rotation${NC}"
echo -e "${RED}    - Current client secret will be INVALIDATED${NC}"
echo -e "${RED}    - New client secret will be generated${NC}"
echo -e "${RED}    - All active sessions will need new credentials${NC}"
echo -e "${RED}    - Application downtime expected until credentials updated${NC}\n"

# Confirm
read -p "Are you sure you want to rotate credentials for ${CLIENT_NAME}? (yes/no): " -r
echo ""

if [[ $REPLY != "yes" ]]; then
    echo -e "${YELLOW}Rotation cancelled.${NC}\n"
    exit 0
fi

# Get Cognito details from Terraform
cd "$TERRAFORM_DIR"

echo -e "${YELLOW}Step 1: Retrieving Cognito configuration...${NC}"
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null)
ROTATION_LAMBDA=$(terraform output -raw rotation_lambda_name 2>/dev/null || echo "")

if [ -z "$USER_POOL_ID" ] || [ -z "$CLIENT_ID" ]; then
    echo -e "${RED}Error: Could not retrieve Cognito configuration from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Configuration retrieved${NC}\n"

# Trigger rotation via Lambda (preferred)
if [ -n "$ROTATION_LAMBDA" ]; then
    echo -e "${YELLOW}Step 2: Triggering rotation via Lambda...${NC}"

    aws lambda invoke \
        --function-name "$ROTATION_LAMBDA" \
        --payload "{\"action\":\"check_rotation\",\"force_client\":\"${CLIENT_ID}\"}" \
        /tmp/rotation-response.json

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Rotation triggered successfully${NC}\n"

        echo -e "${BLUE}What happens next:${NC}"
        echo -e "  1. Lambda function will rotate the client secret"
        echo -e "  2. New credentials will be sent via email notification"
        echo -e "  3. Update your application with new credentials immediately"
        echo -e "  4. Rotation schedule will be updated (next rotation in 90 days)\n"

        echo -e "${GREEN}Check your email for the new credentials.${NC}\n"
    else
        echo -e "${YELLOW}⚠️  Lambda rotation failed, falling back to manual process${NC}\n"
        ROTATION_LAMBDA=""
    fi
fi

# Manual rotation fallback (if Lambda not available)
if [ -z "$ROTATION_LAMBDA" ]; then
    echo -e "${YELLOW}Step 2: Rotating secret manually via AWS CLI...${NC}"

    # Get current client configuration
    CLIENT_CONFIG=$(aws cognito-idp describe-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-id "$CLIENT_ID" \
        --query 'UserPoolClient' \
        --output json)

    CLIENT_NAME_COGNITO=$(echo "$CLIENT_CONFIG" | jq -r '.ClientName')
    ALLOWED_FLOWS=$(echo "$CLIENT_CONFIG" | jq -r '.AllowedOAuthFlows | join(",")')
    ALLOWED_SCOPES=$(echo "$CLIENT_CONFIG" | jq -r '.AllowedOAuthScopes | join(",")')

    # Update client to generate new secret
    UPDATE_RESPONSE=$(aws cognito-idp update-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-id "$CLIENT_ID" \
        --client-name "$CLIENT_NAME_COGNITO" \
        --generate-secret \
        --allowed-o-auth-flows "$ALLOWED_FLOWS" \
        --allowed-o-auth-scopes "$ALLOWED_SCOPES" \
        --allowed-o-auth-flows-user-pool-client \
        --output json)

    NEW_SECRET=$(echo "$UPDATE_RESPONSE" | jq -r '.UserPoolClient.ClientSecret')

    echo -e "${GREEN}✓ Secret rotated successfully${NC}\n"

    # Display new credentials
    echo -e "${BLUE}=== NEW CREDENTIALS ===${NC}\n"
    echo -e "Client ID:     ${GREEN}${CLIENT_ID}${NC}"
    echo -e "Client Secret: ${GREEN}${NEW_SECRET}${NC}\n"

    # Save to file
    CREDS_FILE="../client-credentials/${CLIENT_NAME}-${ENVIRONMENT}-rotated-$(date +%Y%m%d_%H%M%S).txt"
    mkdir -p ../client-credentials

    cat > "$CREDS_FILE" << EOF
# Rotated Credentials for ${CLIENT_NAME} (${ENVIRONMENT})
# Rotation Date: $(date)
# IMPORTANT: Update your application immediately

export CLIENT_ID="${CLIENT_ID}"
export CLIENT_SECRET="${NEW_SECRET}"
EOF

    echo -e "${GREEN}✓ Credentials saved to: ${CREDS_FILE}${NC}\n"

    echo -e "${YELLOW}⚠️  NEXT STEPS:${NC}"
    echo -e "  1. Update your application with the new credentials"
    echo -e "  2. Test authentication to verify it works"
    echo -e "  3. Securely share credentials with the client team"
    echo -e "  4. Delete the credentials file after sharing\n"
fi

echo -e "${BLUE}=== Rotation Complete ===${NC}\n"
