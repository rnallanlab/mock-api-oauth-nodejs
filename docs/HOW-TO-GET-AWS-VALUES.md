# How to Get AWS Configuration Values from Console

This guide shows you how to find the values needed for API testing from the AWS Console.

## Prerequisites
- Access to AWS Console
- Deployed Cognito User Pool and API Gateway

---

## 1. Getting Cognito Values

### **COGNITO_DOMAIN**

1. Go to **AWS Console** → **Amazon Cognito**
2. Click **User pools** in the left sidebar
3. Click on your user pool: `orders-api-dev-pool`
4. In the left sidebar, click **App integration** tab
5. Scroll down to **Domain** section
6. You'll see something like: `my-app-domain-abc123.auth.us-east-1.amazoncognito.com`
7. **Copy only the first part**: `my-app-domain-abc123`

**Example:**
```
Full domain: my-app-domain-abc123.auth.us-east-1.amazoncognito.com
COGNITO_DOMAIN = "my-app-domain-abc123"
```

---

### **CLIENT_ID**

1. Still in your user pool page
2. Click **App integration** tab in the left sidebar
3. Scroll down to **App clients and analytics** section
4. Click on your app client name (e.g., `orders-api-dev-pool-client`)
5. Under **App client information**, find **Client ID**
6. Copy the value (looks like `1a2b3c4d5e6f7g8h9i0j1k2l3m`)

**Example:**
```
CLIENT_ID = "1a2b3c4d5e6f7g8h9i0j1k2l3m"
```

---

### **CLIENT_SECRET**

1. On the same app client page (from CLIENT_ID step)
2. Find **Client secret** under **App client information**
3. Click **Show client secret** button
4. Copy the secret value (looks like a long alphanumeric string)

**Example:**
```
CLIENT_SECRET = "abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
```

**⚠️ Security Note:** Keep this secret confidential. Don't commit it to git.

---

### **REGION**

This is the AWS region where you deployed your resources.

1. Look at the top right corner of AWS Console
2. You'll see the region name (e.g., **N. Virginia**)
3. The region code is shown in parentheses or you can reference this table:

| Region Name       | Region Code    |
|-------------------|----------------|
| US East (N. Virginia) | us-east-1  |
| US East (Ohio)    | us-east-2      |
| US West (N. California) | us-west-1 |
| US West (Oregon)  | us-west-2      |
| Europe (Ireland)  | eu-west-1      |
| Europe (Frankfurt)| eu-central-1   |
| Asia Pacific (Singapore) | ap-southeast-1 |
| Asia Pacific (Tokyo) | ap-northeast-1 |

**Example:**
```
REGION = "us-east-1"
```

---

## 2. Getting API Gateway Values

### **API_ENDPOINT**

1. Go to **AWS Console** → **API Gateway**
2. Click on your API: `orders-api-dev`
3. In the left sidebar, click **Stages**
4. Click on your stage: `v1`
5. At the top, you'll see **Invoke URL**
6. Copy the full URL (looks like `https://abc123xyz.execute-api.us-east-1.amazonaws.com/v1`)

**Example:**
```
API_ENDPOINT = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/v1"
```

---

### **API_KEY**

1. Still in **API Gateway** console
2. In the left sidebar, click **API Keys**
3. Find your key (e.g., `demo-client`)
4. Click on the key name
5. Click **Show** next to **API key**
6. Copy the value (looks like a long alphanumeric string)

**Example:**
```
API_KEY = "Abc1Def2Ghi3Jkl4Mno5Pqr6Stu7Vwx8Yz90AbCdEf"
```

**⚠️ Security Note:** Keep this key confidential. Don't commit it to git.

---

## 3. Using Terraform Outputs (Alternative Method)

If you have terraform installed and state files available, you can get all values at once:

```bash
cd terraform
terraform output -json
```

This will show all values including:
- `cognito_user_pool_domain`
- `cognito_client_id`
- `cognito_client_secret`
- `api_endpoint`
- `api_key_values`

---

## Quick Reference: Navigation Summary

| Value | AWS Service | Navigation Path |
|-------|-------------|-----------------|
| COGNITO_DOMAIN | Cognito | User pools → [your pool] → App integration → Domain |
| CLIENT_ID | Cognito | User pools → [your pool] → App integration → App clients → [client] |
| CLIENT_SECRET | Cognito | User pools → [your pool] → App integration → App clients → [client] → Show secret |
| REGION | Console | Top right corner |
| API_ENDPOINT | API Gateway | APIs → [your API] → Stages → [stage] → Invoke URL |
| API_KEY | API Gateway | API Keys → [your key] → Show |

---

## Testing Your Configuration

Once you have all values, update the `test-api.sh` script with your values and run:

```bash
./test-api.sh
```

This will verify that all configurations are correct and the API is working properly.
