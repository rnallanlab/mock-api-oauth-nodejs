#!/bin/bash

#############################################################################
# OAuth 2.0 Client Credentials Flow - API Demo
#############################################################################
# This script demonstrates how to authenticate with AWS Cognito using
# OAuth 2.0 Client Credentials flow and call the Orders API.
#############################################################################

# Configuration Constants (replace with your actual values)
COGNITO_DOMAIN="https://your-domain.auth.us-east-1.amazoncognito.com"
CLIENT_ID="your_client_id_here"
CLIENT_SECRET="your_client_secret_here"
API_ENDPOINT="https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod"
API_KEY="your_api_key_here"

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}OAuth 2.0 Client Credentials Flow Demo${NC}"
echo -e "${BLUE}========================================${NC}\n"

#############################################################################
# STEP 1: Obtain Access Token from Cognito
#############################################################################
echo -e "${YELLOW}STEP 1: Obtain Access Token from Cognito${NC}"
echo -e "${BLUE}Endpoint:${NC} ${COGNITO_DOMAIN}/oauth2/token"
echo -e "${BLUE}Method:${NC} POST"
echo -e "${BLUE}Grant Type:${NC} client_credentials"
echo ""

# Make the OAuth token request
TOKEN_RESPONSE=$(curl -s -X POST "${COGNITO_DOMAIN}/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

# Extract access token from response
ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
EXPIRES_IN=$(echo $TOKEN_RESPONSE | jq -r '.expires_in')
TOKEN_TYPE=$(echo $TOKEN_RESPONSE | jq -r '.token_type')

if [ "$ACCESS_TOKEN" != "null" ] && [ -n "$ACCESS_TOKEN" ]; then
    echo -e "${GREEN}✓ Successfully obtained access token${NC}"
    echo -e "Token Type: ${TOKEN_TYPE}"
    echo -e "Expires In: ${EXPIRES_IN} seconds"
    echo -e "Access Token (first 30 chars): ${ACCESS_TOKEN:0:30}..."
else
    echo -e "${RED}✗ Failed to obtain access token${NC}"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo ""

#############################################################################
# STEP 2: Test Health Check Endpoint (No Authentication Required)
#############################################################################
echo -e "${YELLOW}STEP 2: Test Health Check Endpoint${NC}"
echo -e "${BLUE}Endpoint:${NC} ${API_ENDPOINT}/health"
echo -e "${BLUE}Method:${NC} GET"
echo -e "${BLUE}Authentication:${NC} None required"
echo ""

HEALTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X GET "${API_ENDPOINT}/health")

HTTP_STATUS=$(echo "$HEALTH_RESPONSE" | grep HTTP_STATUS | cut -d':' -f2)
RESPONSE_BODY=$(echo "$HEALTH_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed (HTTP 200)${NC}"
    echo "Response: $RESPONSE_BODY"
else
    echo -e "${RED}✗ Health check failed (HTTP $HTTP_STATUS)${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""

#############################################################################
# STEP 3: Test Unauthorized Access (No Token)
#############################################################################
echo -e "${YELLOW}STEP 3: Test Unauthorized Access${NC}"
echo -e "${BLUE}Endpoint:${NC} ${API_ENDPOINT}/orders?customerId=CUST12345"
echo -e "${BLUE}Method:${NC} GET"
echo -e "${BLUE}Authentication:${NC} None (should fail)"
echo ""

UNAUTH_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X GET "${API_ENDPOINT}/orders?customerId=CUST12345")

HTTP_STATUS=$(echo "$UNAUTH_RESPONSE" | grep HTTP_STATUS | cut -d':' -f2)
RESPONSE_BODY=$(echo "$UNAUTH_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "403" ]; then
    echo -e "${GREEN}✓ Correctly rejected unauthorized request (HTTP $HTTP_STATUS)${NC}"
    echo "Response: $RESPONSE_BODY"
else
    echo -e "${RED}✗ Expected 401/403, got HTTP $HTTP_STATUS${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""

#############################################################################
# STEP 4: List Orders for Customer (Authenticated)
#############################################################################
echo -e "${YELLOW}STEP 4: List Orders for Customer${NC}"
echo -e "${BLUE}Endpoint:${NC} ${API_ENDPOINT}/orders?customerId=CUST12345"
echo -e "${BLUE}Method:${NC} GET"
echo -e "${BLUE}Headers:${NC}"
echo -e "  - Authorization: Bearer \${ACCESS_TOKEN}"
echo -e "  - x-api-key: \${API_KEY}"
echo ""

ORDERS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X GET "${API_ENDPOINT}/orders?customerId=CUST12345" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$ORDERS_RESPONSE" | grep HTTP_STATUS | cut -d':' -f2)
RESPONSE_BODY=$(echo "$ORDERS_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Successfully retrieved orders (HTTP 200)${NC}"
    echo "Response (formatted):"
    echo "$RESPONSE_BODY" | jq '.'
else
    echo -e "${RED}✗ Failed to retrieve orders (HTTP $HTTP_STATUS)${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""

#############################################################################
# STEP 5: Get Order by ID (Authenticated)
#############################################################################
echo -e "${YELLOW}STEP 5: Get Order by ID${NC}"
echo -e "${BLUE}Endpoint:${NC} ${API_ENDPOINT}/orders/ORD00001"
echo -e "${BLUE}Method:${NC} GET"
echo -e "${BLUE}Headers:${NC}"
echo -e "  - Authorization: Bearer \${ACCESS_TOKEN}"
echo -e "  - x-api-key: \${API_KEY}"
echo ""

ORDER_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X GET "${API_ENDPOINT}/orders/ORD00001" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$ORDER_RESPONSE" | grep HTTP_STATUS | cut -d':' -f2)
RESPONSE_BODY=$(echo "$ORDER_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Successfully retrieved order (HTTP 200)${NC}"
    echo "Response (formatted):"
    echo "$RESPONSE_BODY" | jq '.'
else
    echo -e "${RED}✗ Failed to retrieve order (HTTP $HTTP_STATUS)${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""

#############################################################################
# STEP 6: List Orders with Filters (Date Range, Pagination)
#############################################################################
echo -e "${YELLOW}STEP 6: List Orders with Filters${NC}"
echo -e "${BLUE}Endpoint:${NC} ${API_ENDPOINT}/orders?customerId=CUST12345&startDate=2024-01-01&endDate=2024-12-31&limit=5&offset=0"
echo -e "${BLUE}Method:${NC} GET"
echo -e "${BLUE}Query Parameters:${NC}"
echo -e "  - customerId: CUST12345"
echo -e "  - startDate: 2024-01-01"
echo -e "  - endDate: 2024-12-31"
echo -e "  - limit: 5"
echo -e "  - offset: 0"
echo ""

FILTERED_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X GET "${API_ENDPOINT}/orders?customerId=CUST12345&startDate=2024-01-01&endDate=2024-12-31&limit=5&offset=0" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}")

HTTP_STATUS=$(echo "$FILTERED_RESPONSE" | grep HTTP_STATUS | cut -d':' -f2)
RESPONSE_BODY=$(echo "$FILTERED_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Successfully retrieved filtered orders (HTTP 200)${NC}"
    echo "Response (formatted):"
    echo "$RESPONSE_BODY" | jq '.'
else
    echo -e "${RED}✗ Failed to retrieve filtered orders (HTTP $HTTP_STATUS)${NC}"
    echo "Response: $RESPONSE_BODY"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Demo completed!${NC}"
echo -e "${BLUE}========================================${NC}"
