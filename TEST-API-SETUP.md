# Test API Setup Guide

## Quick Setup (Using Template)

### 1. Copy the template
```bash
cp test-api.sh.template test-api.sh
```

### 2. Get credentials from Terraform
```bash
cd terraform

# Get all values at once
echo "API_ENDPOINT=$(terraform output -raw api_endpoint)"
echo "COGNITO_DOMAIN=$(terraform output -raw cognito_user_pool_domain)"
echo "CLIENT_ID=$(terraform output -raw cognito_client_id)"
echo "CLIENT_SECRET=$(terraform output -raw cognito_client_secret)"
echo "API_KEY=$(terraform output -json api_key_values | jq -r '.["demo-client"]')"

cd ..
```

### 3. Edit test-api.sh
Replace the placeholders on lines 29-34:
```bash
API_ENDPOINT="YOUR_API_ENDPOINT"          # Replace with actual endpoint
COGNITO_DOMAIN="YOUR_COGNITO_DOMAIN"      # Replace with actual domain
COGNITO_REGION="us-east-1"                # Change if different region
CLIENT_ID="YOUR_CLIENT_ID"                # Replace with actual client ID
CLIENT_SECRET="YOUR_CLIENT_SECRET"        # Replace with actual secret
API_KEY="YOUR_API_KEY"                    # Replace with actual API key
```

### 4. Make executable and run
```bash
chmod +x test-api.sh
./test-api.sh
```

## One-Liner Setup (Advanced)

Generate test-api.sh automatically from Terraform outputs:

```bash
cd terraform && cat > ../test-api.sh << 'SCRIPT_END'
#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_ENDPOINT="$(terraform output -raw api_endpoint)"
COGNITO_DOMAIN="$(terraform output -raw cognito_user_pool_domain)"
COGNITO_REGION="us-east-1"
CLIENT_ID="$(terraform output -raw cognito_client_id)"
CLIENT_SECRET="$(terraform output -raw cognito_client_secret)"
API_KEY="$(terraform output -json api_key_values | jq -r '.["demo-client"]')"
SCRIPT_END

cat ../test-api.sh.template | tail -n +28 >> ../test-api.sh
chmod +x ../test-api.sh
cd ..
```

## What the Test Script Does

### 7 Comprehensive Tests:
1. ✅ **Health Check** - No authentication required
2. ✅ **OAuth Token** - Client Credentials flow
3. ✅ **List Orders** - Pagination test (limit 3)
4. ✅ **Get Order by ID** - Single order retrieval
5. ✅ **Date Filtering** - Query by date range
6. ✅ **404 Error** - Invalid order ID handling
7. ✅ **403 Error** - Missing API key handling

## Files

- `test-api.sh.template` - Template with placeholders (✅ committed to git)
- `test-api.sh` - Your copy with real credentials (❌ gitignored)

## Security Note

**Never commit test-api.sh!** It contains sensitive credentials.

The file is already in `.gitignore` so it won't be committed accidentally:
```
# Sensitive: Test scripts with real credentials
test-api.sh
scripts/test-api.sh
```

## Troubleshooting

### "YOUR_* values not replaced"
Make sure you edited the file and replaced all placeholder values.

### "command not found: jq"
Install jq: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### "Unauthorized" errors
1. Check your credentials are correct
2. Verify token was generated: look for "✓ PASSED" in Test 2
3. Make sure API key is included in requests

### "Cannot find terraform outputs"
Make sure you're in the terraform directory when running output commands.

## Example Output

```
========================================
Orders API Test Suite
========================================

Test 1: Health Check (No Auth)
GET https://njo242z8c6.execute-api.us-east-1.amazonaws.com/v1/health

✓ PASSED
{
  "status": "healthy",
  "timestamp": "2025-10-08T17:19:18.551Z"
}

Test 2: Get OAuth Token
POST https://orders-api-dev-xzav2baw.auth.us-east-1.amazoncognito.com/oauth2/token

✓ PASSED
Token expires in: 3600 seconds
Token type: Bearer

... [5 more tests] ...

========================================
Test Suite Complete
========================================

All critical tests passed!
```
