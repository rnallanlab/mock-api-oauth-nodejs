# Client Onboarding Guide

This document describes how to onboard a new client/team to use the Orders API.

## Table of Contents
- [Overview](#overview)
- [Platform Team: Provisioning Steps](#platform-team-provisioning-steps)
- [Client Team: Integration Steps](#client-team-integration-steps)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)

## Overview

The Orders API uses OAuth 2.0 Client Credentials flow with AWS Cognito for authentication. Each client needs:
1. Cognito App Client (Client ID + Secret)
2. API Gateway API Key
3. API endpoint URL

## Platform Team: Provisioning Steps

### Step 1: Create Cognito App Client

```bash
cd terraform/environments/dev

# Add new client to terraform.tfvars
# Edit terraform.tfvars and add to cognito_app_clients list:
# cognito_app_clients = [
#   "demo-client",
#   "new-client-name"  # Add this
# ]

# Apply changes
terraform apply
```

### Step 2: Create API Key

```bash
# Add new API key to terraform.tfvars
# Edit terraform.tfvars and add to api_keys list:
# api_keys = [
#   "demo-client",
#   "new-client-name"  # Add this
# ]

# Apply changes
terraform apply
```

### Step 3: Retrieve Client Credentials

```bash
cd terraform

# Get Cognito domain
export COGNITO_DOMAIN=$(terraform output -raw cognito_user_pool_domain)

# Get Client ID
export CLIENT_ID=$(terraform output -raw cognito_client_id)

# Get Client Secret (for specific client)
export CLIENT_SECRET=$(terraform output -raw cognito_client_secret)

# Get API endpoint
export API_ENDPOINT=$(terraform output -raw api_endpoint)

# Get API Key (for specific client)
export API_KEY=$(terraform output -json api_key_values | jq -r '."new-client-name"')

# Print all values for client
echo "=== Client Credentials ==="
echo "COGNITO_DOMAIN: $COGNITO_DOMAIN"
echo "CLIENT_ID: $CLIENT_ID"
echo "CLIENT_SECRET: $CLIENT_SECRET"
echo "API_ENDPOINT: $API_ENDPOINT"
echo "API_KEY: $API_KEY"
echo "REGION: us-east-1"
```

### Step 4: Securely Share Credentials

**Security Options:**
- AWS Secrets Manager (recommended)
- Encrypted email (PGP/GPG)
- Secure credential sharing platform
- Password-protected encrypted file

**Never share via:**
- Plain text email
- Slack/Teams messages
- Unencrypted files
- Git repositories

### Step 5: Provide Integration Documentation

Share this document with the client team or provide them with the [Client Team Integration Steps](#client-team-integration-steps) section below.

---

## Client Team: Integration Steps

### Prerequisites
- `curl` or HTTP client library
- `jq` (for JSON parsing, optional)
- Credentials provided by Platform Team

### Step 1: Store Credentials Securely

**Environment Variables (for testing):**
```bash
export COGNITO_DOMAIN="your-cognito-domain"
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"
export REGION="us-east-1"
export API_ENDPOINT="your-api-endpoint"
export API_KEY="your-api-key"
```

**Production:** Use AWS Secrets Manager, HashiCorp Vault, or your organization's secret management solution.

### Step 2: Obtain Access Token

**Using curl:**
```bash
TOKEN_RESPONSE=$(curl -s -X POST \
  "https://${COGNITO_DOMAIN}.auth.${REGION}.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
EXPIRES_IN=$(echo $TOKEN_RESPONSE | jq -r '.expires_in')

echo "Token obtained, expires in: ${EXPIRES_IN} seconds"
```

**Using Python:**
```python
import requests
import base64

cognito_domain = "your-cognito-domain"
client_id = "your-client-id"
client_secret = "your-client-secret"
region = "us-east-1"

# Get access token
token_url = f"https://{cognito_domain}.auth.{region}.amazoncognito.com/oauth2/token"
auth_header = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()

response = requests.post(
    token_url,
    headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {auth_header}"
    },
    data={"grant_type": "client_credentials"}
)

token_data = response.json()
access_token = token_data["access_token"]
expires_in = token_data["expires_in"]
```

**Using Node.js:**
```javascript
const axios = require('axios');

const cognitoDomain = 'your-cognito-domain';
const clientId = 'your-client-id';
const clientSecret = 'your-client-secret';
const region = 'us-east-1';

async function getAccessToken() {
    const tokenUrl = `https://${cognitoDomain}.auth.${region}.amazoncognito.com/oauth2/token`;
    const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

    const response = await axios.post(tokenUrl,
        'grant_type=client_credentials',
        {
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Authorization': `Basic ${auth}`
            }
        }
    );

    return {
        accessToken: response.data.access_token,
        expiresIn: response.data.expires_in
    };
}
```

### Step 3: Call API Endpoints

**Health Check (no auth required):**
```bash
curl -X GET "${API_ENDPOINT}/health"
```

**Get Orders by Customer ID:**
```bash
curl -X GET "${API_ENDPOINT}/orders?customerId=CUST12345" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

**Get Specific Order:**
```bash
curl -X GET "${API_ENDPOINT}/orders/ORD00001" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

### Step 4: Handle Token Expiration

JWT tokens expire (typically 3600 seconds / 1 hour). Implement token refresh logic:

**Python Example:**
```python
from datetime import datetime, timedelta

class APIClient:
    def __init__(self, cognito_domain, client_id, client_secret, api_endpoint, api_key):
        self.cognito_domain = cognito_domain
        self.client_id = client_id
        self.client_secret = client_secret
        self.api_endpoint = api_endpoint
        self.api_key = api_key
        self.access_token = None
        self.token_expiry = None

    def get_token(self):
        if self.access_token and self.token_expiry > datetime.now():
            return self.access_token

        # Token expired or doesn't exist, get new one
        token_url = f"https://{self.cognito_domain}.auth.us-east-1.amazoncognito.com/oauth2/token"
        auth_header = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()

        response = requests.post(
            token_url,
            headers={
                "Content-Type": "application/x-www-form-urlencoded",
                "Authorization": f"Basic {auth_header}"
            },
            data={"grant_type": "client_credentials"}
        )

        token_data = response.json()
        self.access_token = token_data["access_token"]
        self.token_expiry = datetime.now() + timedelta(seconds=token_data["expires_in"] - 60)  # 60s buffer

        return self.access_token

    def get_orders(self, customer_id):
        token = self.get_token()
        response = requests.get(
            f"{self.api_endpoint}/orders",
            params={"customerId": customer_id},
            headers={
                "Authorization": f"Bearer {token}",
                "x-api-key": self.api_key
            }
        )
        return response.json()
```

### Step 5: Test Your Integration

Use the provided test script template:

```bash
# Copy template
cp test-api.sh.template my-test-api.sh

# Configure with your credentials
# Edit my-test-api.sh and set:
# - COGNITO_DOMAIN
# - CLIENT_ID
# - CLIENT_SECRET
# - API_ENDPOINT
# - API_KEY

# Run tests
chmod +x my-test-api.sh
./my-test-api.sh
```

Expected output:
```
=== Testing Orders API ===

Step 1: Getting access token from Cognito...
✓ Access token obtained

Step 2: Testing /health endpoint...
Status: 200
✓ Health check passed

Step 3: Testing GET /orders?customerId=CUST12345...
Status: 200
✓ Get all orders passed

Step 4: Testing GET /orders/ORD00001...
Status: 200
✓ Get order by ID passed

Step 5: Testing GET /orders/INVALID (should return 404)...
Status: 404
✓ 404 response correct

=== Testing Complete ===
```

---

## API Reference

### Available Endpoints

#### Health Check
```
GET /health
```
- **Auth Required:** No
- **Response:** `{ "status": "UP" }`

#### Get Orders by Customer
```
GET /orders?customerId={customerId}
```
- **Auth Required:** Yes (JWT + API Key)
- **Query Parameters:**
  - `customerId` (required): Customer identifier
- **Response:** Array of order objects

#### Get Order by ID
```
GET /orders/{orderId}
```
- **Auth Required:** Yes (JWT + API Key)
- **Path Parameters:**
  - `orderId` (required): Order identifier
- **Response:** Order object or 404 if not found

### Required Headers

For all authenticated endpoints:
```
Authorization: Bearer <jwt-access-token>
x-api-key: <api-key>
```

### Response Codes

- `200 OK` - Success
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Missing or invalid API key
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error

---

## Security Best Practices

### For Client Teams

1. **Store Credentials Securely**
   - Never hardcode credentials in source code
   - Use environment variables for development
   - Use secret management tools for production (AWS Secrets Manager, HashiCorp Vault)
   - Add credential files to `.gitignore`

2. **Implement Token Caching**
   - Cache tokens until expiration
   - Implement automatic token refresh
   - Add 60-second buffer before actual expiry

3. **Use HTTPS Only**
   - All API calls must use HTTPS
   - Never send credentials over HTTP

4. **Implement Retry Logic**
   - Handle 401 errors by refreshing token
   - Implement exponential backoff for retries
   - Set maximum retry attempts

5. **Monitor and Log**
   - Log API errors (but NOT credentials or tokens)
   - Monitor token expiration patterns
   - Alert on authentication failures

### For Platform Teams

1. **Credential Rotation**
   - Rotate client secrets periodically
   - Provide advance notice to clients
   - Support multiple active secrets during rotation

2. **Access Control**
   - Use separate API keys per client
   - Implement usage plans and rate limiting
   - Monitor API key usage

3. **Audit Logging**
   - Log all authentication attempts
   - Monitor for suspicious activity
   - Review CloudWatch logs regularly

---

## Troubleshooting

### Common Issues

#### 1. "Invalid client credentials" error

**Cause:** Incorrect Client ID or Client Secret

**Solution:**
```bash
# Verify credentials from terraform
cd terraform
terraform output cognito_client_id
terraform output cognito_client_secret
```

#### 2. "Invalid API Key" (403 Forbidden)

**Cause:** Missing or incorrect `x-api-key` header

**Solution:**
```bash
# Verify API key
cd terraform
terraform output -json api_key_values | jq -r '."your-client-name"'

# Ensure header is set correctly
curl -H "x-api-key: ${API_KEY}" ...
```

#### 3. "Unauthorized" (401)

**Cause:** Missing, expired, or invalid JWT token

**Solution:**
- Check if token is expired (tokens typically expire in 1 hour)
- Verify `Authorization: Bearer <token>` header format
- Ensure token was obtained successfully from Cognito
- Check token response: `echo $TOKEN_RESPONSE | jq`

#### 4. "Token signature verification failed"

**Cause:** Token from wrong Cognito pool or corrupted

**Solution:**
- Verify using correct Cognito domain
- Obtain a fresh token
- Check for whitespace or encoding issues in token

#### 5. Connection timeout or DNS errors

**Cause:** Incorrect API endpoint or Cognito domain

**Solution:**
```bash
# Verify endpoints
cd terraform
echo "Cognito: https://$(terraform output -raw cognito_user_pool_domain).auth.us-east-1.amazoncognito.com"
echo "API: $(terraform output -raw api_endpoint)"

# Test connectivity
curl -v https://your-domain.auth.us-east-1.amazoncognito.com/oauth2/token
```

---

## Support

### Client Support Contacts
- **Technical Issues:** [Platform Team Email/Slack Channel]
- **Credential Issues:** [Security Team Contact]
- **API Documentation:** See `README.md` and `ARCHITECTURE.md` in repository

### Platform Team Resources
- **Terraform Code:** `/terraform` directory
- **Test Scripts:** `test-api.sh.template`
- **Architecture Docs:** `ARCHITECTURE.md`
- **Deployment Status:** `DEPLOYMENT-STATUS.md`

---

## Appendix: Quick Reference

### Terraform Commands for Client Management

```bash
# Add new client
cd terraform/environments/dev
# Edit terraform.tfvars:
# - Add to cognito_app_clients list
# - Add to api_keys list
terraform apply

# Get client credentials
terraform output cognito_client_id
terraform output cognito_client_secret
terraform output -json api_key_values | jq -r '."client-name"'

# Remove client
# Edit terraform.tfvars:
# - Remove from cognito_app_clients list
# - Remove from api_keys list
terraform apply
```

### Environment Variable Template

```bash
# Save as .env (add to .gitignore!)
export COGNITO_DOMAIN="your-cognito-domain"
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"
export REGION="us-east-1"
export API_ENDPOINT="https://your-api.execute-api.us-east-1.amazonaws.com/v1"
export API_KEY="your-api-key"
```

---

**Last Updated:** 2025-10-06
**Version:** 1.0
