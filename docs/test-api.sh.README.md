# Test API Script Setup

This file explains how to use `test-api.sh.template` to test your deployed API.

## Quick Setup

1. **Copy the template:**
   ```bash
   cp test-api.sh.template test-api.sh
   ```

2. **Get credentials from Terraform:**
   ```bash
   cd terraform

   export COGNITO_DOMAIN=$(terraform output -raw cognito_user_pool_domain)
   export CLIENT_ID=$(terraform output -raw cognito_client_id)
   export CLIENT_SECRET=$(terraform output -raw cognito_client_secret)
   export API_ENDPOINT=$(terraform output -raw api_endpoint)
   export API_KEY=$(terraform output -json api_key_values | jq -r '.["demo-client"]')
   ```

3. **Run the test script:**
   ```bash
   cd ..
   ./test-api.sh
   ```

## Manual Setup (Alternative)

If you prefer to edit the file manually:

1. Copy the template:
   ```bash
   cp test-api.sh.template test-api.sh
   ```

2. Edit `test-api.sh` and replace these values:
   - `YOUR_COGNITO_DOMAIN` - Get from: `terraform output cognito_user_pool_domain`
   - `YOUR_CLIENT_ID` - Get from: `terraform output cognito_client_id`
   - `YOUR_CLIENT_SECRET` - Get from: `terraform output cognito_client_secret`
   - `YOUR_API_ENDPOINT` - Get from: `terraform output api_endpoint`
   - `YOUR_API_KEY` - Get from: `terraform output api_key_values`

3. Make it executable:
   ```bash
   chmod +x test-api.sh
   ```

4. Run it:
   ```bash
   ./test-api.sh
   ```

## Security Note

**NEVER commit `test-api.sh` to git!**

The file contains sensitive credentials and is already in `.gitignore`. Only commit the `.template` file.

## Expected Output

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
