# Architecture Documentation

## Overview

This document describes the current architecture of the Mock Orders API, including infrastructure components, security model, and data flow.

## System Architecture

### High-Level Component Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                           AWS Cloud (us-east-1)                      │
│                                                                      │
│  ┌────────────────┐                                                 │
│  │  AWS Cognito   │                                                 │
│  │  User Pool     │                                                 │
│  │                │                                                 │
│  │  - Client ID   │                                                 │
│  │  - Client Sec  │                                                 │
│  │  - OAuth 2.0   │                                                 │
│  └───────┬────────┘                                                 │
│          │ (1) Token Request                                        │
│          │                                                          │
│  ┌───────▼────────────────────────────────────────────────────┐    │
│  │              API Gateway (REST API)                        │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │  Resource: /health                                   │  │    │
│  │  │  - No authentication required                        │  │    │
│  │  │  - No API key required                               │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │  Resource: /orders                                   │  │    │
│  │  │  - Custom Lambda Authorizer (JWT validation)         │  │    │
│  │  │  - API Key REQUIRED                                  │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────────────────────┐  │    │
│  │  │  Resource: /orders/{orderId}                         │  │    │
│  │  │  - Custom Lambda Authorizer (JWT validation)         │  │    │
│  │  │  - API Key REQUIRED                                  │  │    │
│  │  └──────────────────────────────────────────────────────┘  │    │
│  └────────┬──────────────────────────┬──────────────────────┘    │
│           │ (2) Invoke Authorizer     │ (3) Invoke Lambda         │
│           │                           │                           │
│  ┌────────▼─────────────┐    ┌───────▼──────────────────────┐   │
│  │  Lambda Authorizer   │    │   Main Lambda Function       │   │
│  │  (Node.js 18)        │    │   (Java 21 + Spring Boot)    │   │
│  │                      │    │                              │   │
│  │  - Fetch JWKS        │    │  - OrdersController          │   │
│  │  - Validate JWT sig  │    │  - HealthController          │   │
│  │  - Check issuer      │    │  - MockOrderService          │   │
│  │  - Check expiry      │    │  - ClientMetricsService      │   │
│  │  - Return IAM policy │    │  - Spring Security JWT       │   │
│  └──────────────────────┘    └──────────────────────────────┘   │
│                                         │                         │
│                                         │ (4) Publish metrics      │
│                                         ▼                         │
│                              ┌────────────────────┐               │
│                              │ CloudWatch Metrics │               │
│                              │ & Logs             │               │
│                              └────────────────────┘               │
└──────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### API Gateway Security Model

The API implements **centralized security at API Gateway** using a custom Lambda Authorizer. This provides a flexible, provider-agnostic authentication layer.

#### Security Components

1. **API Gateway - API Key Validation**
   - Required for: `/orders` and `/orders/{orderId}`
   - Not required for: `/health`
   - Provides basic client identification
   - Associated with usage plans for rate limiting

2. **API Gateway - Custom Lambda Authorizer**
   - Type: REQUEST authorizer
   - Identity Source: `Authorization` header
   - Cache TTL: 300 seconds (5 minutes)
   - Returns: IAM policy (Allow/Deny)

3. **Lambda Authorizer (Node.js)**
   - Validates JWT signature using Cognito JWKS
   - Checks standard JWT claims (iss, exp)
   - Validates Cognito-specific claims (token_use)
   - Returns context data to main Lambda

4. **Main Lambda (Java/Spring Boot)**
   - Receives pre-authorized requests
   - Has access to user context from authorizer
   - Processes business logic
   - Can optionally validate JWT for defense-in-depth (future enhancement)

### Authentication Flow

#### Client Credentials Flow (OAuth 2.0)

```
┌────────┐                                          ┌────────────┐
│ Client │                                          │  Cognito   │
│  App   │                                          │ User Pool  │
└───┬────┘                                          └─────┬──────┘
    │                                                     │
    │ (1) POST /oauth2/token                             │
    │     Authorization: Basic base64(client_id:secret)  │
    │     grant_type=client_credentials                  │
    ├────────────────────────────────────────────────────>│
    │                                                     │
    │ (2) { access_token: "eyJ...", expires_in: 3600 }   │
    │<────────────────────────────────────────────────────┤
    │                                                     │
    │                                                     │
┌───┴────┐              ┌─────────────┐         ┌────────────────┐
│ Client │              │ API Gateway │         │    Lambda      │
│  App   │              │             │         │  Authorizer    │
└───┬────┘              └──────┬──────┘         └────────┬───────┘
    │                          │                         │
    │ (3) GET /orders?customerId=CUST12345               │
    │     Authorization: Bearer eyJ...                   │
    │     x-api-key: abc123                              │
    ├─────────────────────────>│                         │
    │                          │                         │
    │                          │ (4) Validate API Key    │
    │                          │     ✓ Valid             │
    │                          │                         │
    │                          │ (5) Invoke authorizer   │
    │                          │     Event: { token }    │
    │                          ├────────────────────────>│
    │                          │                         │
    │                          │                         │ (6) Fetch JWKS
    │                          │                         │     from Cognito
    │                          │                         │
    │                          │                         │ (7) Verify JWT
    │                          │                         │     - Signature ✓
    │                          │                         │     - Issuer ✓
    │                          │                         │     - Expiry ✓
    │                          │                         │     - token_use ✓
    │                          │                         │
    │                          │ (8) Return IAM Policy   │
    │                          │     Effect: Allow       │
    │                          │<────────────────────────┤
    │                          │                         │
    │                          │                         │
    │           ┌──────────────┴───────────┐             │
    │           │                          │             │
    │           │    Main Lambda Function  │             │
    │           │    (Java/Spring Boot)    │             │
    │           │                          │             │
    │           │ (9) Process request      │             │
    │           │     - Find orders        │             │
    │           │     - Return data        │             │
    │           │                          │             │
    │           └──────────────┬───────────┘             │
    │                          │                         │
    │ (10) { orders: [...] }   │                         │
    │<─────────────────────────┤                         │
    │                          │                         │
```

### JWT Token Structure

#### Cognito Access Token (Client Credentials)

```json
{
  "header": {
    "kid": "abc123...",
    "alg": "RS256"
  },
  "payload": {
    "sub": "{client-id}",
    "token_use": "access",
    "scope": "orders-api/read",
    "auth_time": 1696123456,
    "iss": "https://cognito-idp.{region}.amazonaws.com/{user-pool-id}",
    "exp": 1696127056,
    "iat": 1696123456,
    "version": 2,
    "jti": "uuid-here",
    "client_id": "{client-id}"
  }
}
```

**Key Claims Validated:**
- `iss` - Must match Cognito User Pool issuer
- `exp` - Token must not be expired
- `token_use` - Must be "access" (not "id")
- Signature - Validated using Cognito JWKS public key

## Infrastructure Components

### Terraform Modules

```
terraform/
├── main.tf                    # Root module, orchestrates deployment
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
└── modules/
    ├── cognito/               # Cognito User Pool & App Client
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── authorizer/            # Lambda Authorizer (Node.js)
    │   ├── main.tf
    │   ├── index.js           # Authorizer logic
    │   ├── package.json
    │   └── authorizer.zip     # Deployment package
    ├── lambda/                # Main Lambda (Java/Spring Boot)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── apigateway/            # API Gateway REST API
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### AWS Resources Created

| Resource Type | Name | Purpose |
|--------------|------|---------|
| Cognito User Pool | `orders-api-dev-pool` | OAuth 2.0 identity provider |
| Cognito User Pool Client | Auto-generated | App client for authentication |
| Cognito User Pool Domain | `orders-api-dev-{random}` | OAuth 2.0 token endpoint |
| Lambda Function | `orders-api-dev-authorizer` | JWT validation |
| Lambda Function | `orders-api-dev` | Main application logic |
| API Gateway REST API | `orders-api-dev` | HTTP API endpoint |
| API Gateway Authorizer | `orders-api-dev-jwt-authorizer` | Custom authorizer |
| API Gateway API Key | `demo-client` | Client access key |
| API Gateway Usage Plan | `standard` | Rate limiting plan |
| CloudWatch Log Group | `/aws/lambda/orders-api-dev` | Lambda logs |
| CloudWatch Log Group | `/aws/lambda/orders-api-dev-authorizer` | Authorizer logs |
| IAM Role | `orders-api-dev-execution-role` | Lambda execution |
| IAM Role | `orders-api-dev-authorizer-role` | Authorizer execution |
| IAM Role | `orders-api-dev-authorizer-invocation-role` | API Gateway to Lambda |

## Application Architecture

### Java Application Structure

```
server/src/main/java/com/example/orders/
├── controller/
│   ├── HealthController.java          # /health endpoint
│   └── OrdersController.java          # /orders endpoints
├── model/
│   ├── Order.java                     # Order entity
│   ├── OrderItem.java                 # Order item entity
│   ├── OrderStatus.java               # Enum for order status
│   └── OrdersResponse.java            # Response wrapper
├── service/
│   ├── MockOrderService.java          # Mock data service
│   └── ClientMetricsService.java      # Metrics recording
└── filter/
    └── RequestLoggingFilter.java      # HTTP request logging
```

### Key Design Decisions

1. **Defense-in-Depth Security**
   - Lambda Authorizer validates JWT at API Gateway layer
   - Spring Security validates JWT at application layer
   - Double validation provides robust security
   - Reduces cold start time
   - API Gateway handles all security

2. **Mock Data Service**
   - Generates 100 orders at startup
   - 5 customer IDs: CUST12345, CUST67890, CUST11111, CUST22222, CUST33333
   - Orders span 2 years of history
   - Random order statuses and items

3. **Metrics Integration**
   - Micrometer for metrics collection
   - CloudWatch as metrics backend
   - Tracks request counts and latency
   - Per-client metrics tracking

4. **API Key Tracking**
   - Extracts client ID from API key hash
   - Used for metrics attribution
   - No user context from JWT (since removed Authentication param)

## Deployment Process

### Build Pipeline

```bash
# 1. Build Java application
cd server
mvn clean package
# Output: target/mock-api-oauth-aws-1.0.0.jar

# 2. Package Lambda authorizer
cd terraform/modules/authorizer
npm install
zip -r authorizer.zip index.js node_modules/

# 3. Deploy infrastructure
cd terraform
terraform init
terraform apply -var="deployment_type=lambda"
```

### Deployment Sequence

1. Create Cognito User Pool and App Client
2. Deploy Lambda Authorizer
3. Deploy Main Lambda Function
4. Create API Gateway with authorizer
5. Create API keys and usage plans
6. Associate API keys with usage plans

## Monitoring & Observability

### CloudWatch Logs

- **Lambda Function:** `/aws/lambda/orders-api-dev`
  - Application logs
  - Request/response data
  - Error traces

- **Lambda Authorizer:** `/aws/lambda/orders-api-dev-authorizer`
  - JWT validation logs
  - Authorization decisions
  - JWKS fetch operations

### CloudWatch Metrics

**Custom Metrics (via Micrometer):**
- `orders.list` - Time to list orders
- `orders.getById` - Time to get order by ID
- Request counts per client
- Error counts per client

**AWS Lambda Metrics:**
- Invocations
- Duration
- Errors
- Throttles
- Concurrent executions

**API Gateway Metrics:**
- 4xx errors
- 5xx errors
- Latency
- Cache hit/miss

## Performance Characteristics

### Cold Start Performance

| Component | Cold Start | Warm Invocation |
|-----------|-----------|-----------------|
| Lambda Authorizer (Node.js) | ~500ms | ~50ms |
| Main Lambda (Java/Spring Boot) | ~4-6s | ~100-300ms |
| API Gateway | N/A | ~10ms |

### Caching Strategy

1. **API Gateway Authorizer Cache**
   - TTL: 300 seconds (5 minutes)
   - Caches authorization decisions
   - Reduces Lambda Authorizer invocations

2. **JWKS Cache (in Authorizer)**
   - Caches Cognito public keys
   - Rate limited to 10 requests/minute
   - Reduces calls to Cognito

## Extensibility & Design Patterns

### Multi-Provider Authentication Support

The Lambda Authorizer is designed to support multiple OAuth/OIDC providers through configuration:

**Currently Supported:**
- AWS Cognito (default)
- Azure AD

**Environment Variables:**
```javascript
PROVIDER_TYPE = 'cognito' | 'azure'
JWKS_URI     = 'https://provider/.well-known/jwks.json'
ISSUER       = 'https://provider/issuer'
AUDIENCE     = 'api://application-id' (optional)
```

**Adding New Providers (e.g., Okta):**

1. Add provider-specific validation in `terraform/modules/authorizer/index.js`
2. Configure JWKS URI and issuer in Terraform variables
3. No changes needed in main Lambda application

**Example Okta Configuration:**
```hcl
module "authorizer" {
  auth_provider = "okta"
  jwks_uri     = "https://dev-12345.okta.com/oauth2/default/v1/keys"
  issuer       = "https://dev-12345.okta.com/oauth2/default"
  audience     = "api://orders-api"
}
```

### Future: Application-Layer Security

The architecture supports adding application-layer JWT validation:

1. Spring Security already validates JWT at application layer
2. Configure JWT validation in `application.yml`
3. Use `@Secured` annotations on controllers
4. Extract user context from both authorizer and JWT

This provides **defense-in-depth** while maintaining provider flexibility at the gateway level.

## Security Considerations

### Current Implementation

✅ **Implemented:**
- JWT signature validation (Lambda Authorizer)
- Token expiry validation
- Issuer validation
- Multi-provider support (Cognito, Azure AD)
- API key requirement
- HTTPS only (API Gateway enforces)
- IAM-based Lambda permissions
- User context propagation to application

🔄 **Future Enhancements:**
- Application-layer JWT validation (defense-in-depth)
- Scope/permissions-based authorization
- Request rate limiting per client
- IP whitelisting support
- Additional provider support (Okta, Auth0)
- Request signing for sensitive operations

### Trust Boundary

```
┌─────────────────────────────────────────────────┐
│  SECURITY PERIMETER (API Gateway)               │
│                                                 │
│  ✅ JWT Signature Validation                    │
│  ✅ Token Expiry Check                          │
│  ✅ Issuer Validation                           │
│  ✅ API Key Validation                          │
│                                                 │
│  Only authorized requests pass through          │
└─────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────┐
│  TRUSTED (within AWS)                           │
│                                                 │
│  - Main Lambda Function (receives context)      │
│  - CloudWatch (logs/metrics)                    │
│                                                 │
│  Future: Can add app-layer validation           │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  UNTRUSTED (public internet)                    │
│                                                 │
│  - Client applications                          │
│  - All HTTP requests                            │
│                                                 │
│  Must authenticate via OAuth provider           │
└─────────────────────────────────────────────────┘
```

## API Endpoints Reference

### GET /health

**Authentication:** None
**API Key:** Not required
**Response:** 200 OK

```json
{
  "status": "healthy",
  "timestamp": 1759690530.130585223
}
```

### GET /orders

**Authentication:** JWT Bearer token
**API Key:** Required
**Query Parameters:**
- `customerId` (required) - Customer ID
- `startDate` (optional) - ISO 8601 date
- `endDate` (optional) - ISO 8601 date
- `limit` (optional) - 1-100, default 20
- `offset` (optional) - default 0

**Response:** 200 OK

```json
{
  "orders": [...],
  "totalCount": 20,
  "limit": 20,
  "offset": 0
}
```

### GET /orders/{orderId}

**Authentication:** JWT Bearer token
**API Key:** Required
**Path Parameters:**
- `orderId` - Order ID (e.g., ORD00001)

**Response:** 200 OK (if found) or 404 Not Found

```json
{
  "orderId": "ORD00001",
  "customerId": "CUST12345",
  "orderDate": 1739415196.380661880,
  "status": "CANCELLED",
  "totalAmount": 713.0,
  "currency": "USD",
  "items": [...]
}
```

## Troubleshooting Guide

### Common Issues

1. **401 Unauthorized**
   - Check JWT token is not expired
   - Verify Authorization header format: `Bearer {token}`
   - Check API key is included in `x-api-key` header

2. **403 Forbidden**
   - API key may be invalid or disabled
   - Usage plan may be exceeded

3. **404 Not Found**
   - Check endpoint path includes `/v1` stage
   - Verify order ID exists in mock data

4. **Lambda Timeout**
   - Cold start may take 3-5 seconds
   - Increase Lambda timeout if needed

---

**Last Updated:** 2025-10-05
**Version:** 1.0
