# Orders API - AWS OAuth Client Credentials POC

Production-ready OAuth 2.0 Client Credentials API using AWS Cognito, Lambda Authorizer, and Node.js.

## 🎯 What Is This?

A **proof-of-concept API** demonstrating:
- ✅ OAuth 2.0 Client Credentials flow (machine-to-machine auth)
- ✅ AWS Cognito for identity management
- ✅ Lambda Authorizer for JWT validation
- ✅ Multi-provider support (Cognito, Azure AD, extensible to Okta)
- ✅ API Gateway with API keys and rate limiting
- ✅ Node.js 22.x serverless application
- ✅ Defense-in-depth security with application-layer JWT validation

## 🏗️ Architecture

```
Client → Cognito (OAuth Token) → API Gateway → Lambda Authorizer (JWT Validation) → Lambda (Business Logic)
```

**Security Model:**
- JWT validation at API Gateway (Lambda Authorizer)
- API keys for client identification
- Multi-provider OAuth support
- Token-based authentication with expiration

📖 **[Architecture Details](docs/ARCHITECTURE.md)**

## 🚀 Quick Start

### Prerequisites
- Node.js 22+, npm 10+, Terraform 1.0+, AWS CLI
- AWS Account with appropriate permissions

### 1. Build
```bash
./scripts/build.sh
```

### 2. Deploy
```bash
./scripts/deploy.sh lambda us-east-1 dev
```

### 3. Test
```bash
# Copy template and configure
cp test-api.sh.template test-api.sh
# Edit test-api.sh with your credentials from terraform output

# Run tests
./test-api.sh
```

📖 **[Test Script Setup Guide](docs/test-api.sh.README.md)**

## 📋 API Endpoints

| Endpoint | Auth | Description |
|----------|------|-------------|
| `GET /health` | ❌ No | Health check |
| `GET /orders?customerId={id}` | ✅ Yes | List customer orders |
| `GET /orders/{orderId}` | ✅ Yes | Get order by ID |

**Authentication:**
- `Authorization: Bearer <jwt-token>` (from Cognito)
- `x-api-key: <api-key>` (from API Gateway)

## 📚 Documentation

### Core Documentation
- **[Architecture](docs/ARCHITECTURE.md)** - System design, security model, multi-provider support
- **[Security Model](docs/SECURITY-MODEL.md)** - OAuth 2.0 benefits, security architecture
- **[Deployment Status](docs/DEPLOYMENT-STATUS.md)** - Current deployment state, test results
- **[Current State](docs/CURRENT-STATE.md)** - Working prototype documentation

### Deployment & Operations
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Step-by-step deployment instructions
- **[Client Onboarding](docs/CLIENT-ONBOARDING.md)** - How to onboard new API clients
- **[Test API Setup](docs/test-api.sh.README.md)** - How to test the deployed API
- **[AWS Values Guide](docs/HOW-TO-GET-AWS-VALUES.md)** - Getting AWS configuration values

### Client Management Scripts
Located in `scripts/`:
- `provision-client.sh` - Create new client with Cognito + API key
- `revoke-client.sh` - Revoke client access
- `list-clients.sh` - List all provisioned clients

📖 **[Scripts Documentation](scripts/README.md)**

## 🔐 Client Onboarding

### For Platform Team
```bash
# Provision new client
./scripts/provision-client.sh acme-corp dev

# This creates:
# - Cognito App Client (Client ID + Secret)
# - API Gateway API Key
# - Outputs credentials to share with client team
```

### For Client Team
```bash
# 1. Get access token from Cognito
curl -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials"

# 2. Call API with token
curl -X GET "${API_ENDPOINT}/orders?customerId=CUST12345" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "x-api-key: ${API_KEY}"
```

📖 **[Complete Onboarding Guide](docs/CLIENT-ONBOARDING.md)**

## 🔮 Future Enhancements

Located in `future-enhancements/` (code complete, not deployed):

### GitHub Actions CI/CD
- ✅ Automated Terraform deployments
- ✅ Remote state in S3 with locking
- ✅ OIDC authentication (no AWS keys)
- ✅ PR review workflow

📖 **[CI/CD Setup Guide](future-enhancements/github-actions-cicd/README.md)**

### Credential Rotation
- ✅ 90-day automatic rotation
- ✅ 14-day advance warning
- ✅ Email notifications via SNS
- ✅ No database (uses EventBridge)

📖 **[Credential Rotation Details](future-enhancements/README.md)**

### Scope-Based Authorization (Coming Soon)
- Fine-grained permissions (read-only vs full access)
- Different client tiers
- OAuth scopes enforcement

## 🛠️ Project Structure

```
.
├── docs/                          # All documentation
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT-STATUS.md
│   ├── SECURITY-MODEL.md
│   ├── CLIENT-ONBOARDING.md
│   └── test-api.sh.README.md
│
├── server/                        # Node.js application
│   ├── src/
│   │   ├── config/               # Configuration (JWT, etc.)
│   │   ├── controllers/          # API endpoints
│   │   ├── middleware/           # Request processing
│   │   ├── models/               # Data models
│   │   ├── services/             # Business logic
│   │   ├── app.js                # Main application
│   │   └── lambda.js             # Lambda handler
│   ├── package.json
│   └── build.sh
│
├── terraform/                     # Infrastructure as Code
│   ├── main.tf
│   ├── modules/
│   │   ├── cognito/              # User Pool + App Clients
│   │   ├── authorizer/           # Lambda Authorizer (JWT validation)
│   │   ├── apigateway/           # API Gateway + API Keys
│   │   └── lambda/               # Main Lambda function
│   └── environments/
│       └── dev/
│
├── scripts/                       # Management scripts
│   ├── build.sh                  # Build Lambda package
│   ├── deploy.sh                 # Deploy to AWS
│   ├── provision-client.sh       # Create new client
│   ├── revoke-client.sh          # Revoke client
│   └── list-clients.sh           # List clients
│
├── future-enhancements/           # Ready-to-deploy features (not active)
│   └── secret-rotation/          # Automated credential rotation
│
└── README.md                      # This file
```

## 🔧 Configuration

### Terraform Variables
```hcl
environment     = "dev"
aws_region      = "us-east-1"

# Usage tiers for rate limiting
usage_tiers = {
  "standard" = {
    quota_limit  = 100    # requests/month
    burst_limit  = 5      # burst capacity
    rate_limit   = 1      # req/second
  }
}
```

### Environment Variables
```bash
# Required for deployment
export AWS_REGION=us-east-1
export ENVIRONMENT=dev

# For testing
export COGNITO_DOMAIN=<from terraform output>
export CLIENT_ID=<from terraform output>
export CLIENT_SECRET=<from terraform output>
export API_ENDPOINT=<from terraform output>
export API_KEY=<from terraform output>
```

## 🧹 Cleanup

```bash
cd terraform
terraform destroy
```

## 💰 Cost Estimate (POC)

- **Lambda:** $0 (free tier)
- **API Gateway:** $0 (free tier, <1M requests/month)
- **Cognito:** $0 (free tier, <50K MAUs)
- **CloudWatch Logs:** ~$0.50/month

**Total: ~$0.50/month**

## 🐛 Troubleshooting

### Authentication Issues
```bash
# Check Cognito setup
terraform output cognito_user_pool_domain
terraform output cognito_client_id

# Test token generation
curl -X POST "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials"
```

### API Gateway Issues
```bash
# Check deployment
aws apigateway get-rest-apis

# View Lambda Authorizer logs
aws logs tail /aws/lambda/orders-api-dev-authorizer --follow
```

### Lambda Issues
```bash
# View application logs
aws logs tail /aws/lambda/orders-api-dev --follow
```

## 📖 Key Concepts

### OAuth 2.0 Client Credentials Flow
- **Purpose:** Machine-to-machine authentication (no user involved)
- **Credentials:** Client ID + Client Secret → Access Token
- **Token Lifetime:** 1 hour (configurable)
- **Use Case:** Service-to-service API calls

### Lambda Authorizer (Custom JWT Validation)
- **Location:** API Gateway layer (before Lambda)
- **Function:** Validates JWT signature, issuer, expiration
- **Multi-Provider:** Supports Cognito, Azure AD, Okta
- **Caching:** 5-minute TTL for performance

### API Keys
- **Purpose:** Client identification and rate limiting
- **Required For:** All `/orders` endpoints
- **Not Required For:** `/health` endpoint
- **Usage Plans:** Quotas and throttling per client

## 🛠️ Technology Stack

- **Runtime:** Node.js 22.x
- **Cloud:** AWS Lambda, API Gateway, Cognito
- **IaC:** Terraform
- **Authentication:** OAuth 2.0 Client Credentials (Cognito)
- **Monitoring:** CloudWatch Logs & Metrics

## 🎓 Learn More

- [OAuth 2.0 Client Credentials](https://oauth.net/2/grant-types/client-credentials/)
- [AWS Cognito OAuth Flows](https://docs.aws.amazon.com/cognito/latest/developerguide/cognito-user-pools-app-idp-settings.html)
- [API Gateway Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [AWS Lambda Node.js](https://docs.aws.amazon.com/lambda/latest/dg/lambda-nodejs.html)

## 📄 License

Educational/demo project - Use at your own risk

---

**Built for POC/Learning - Ready for Production Extension**
