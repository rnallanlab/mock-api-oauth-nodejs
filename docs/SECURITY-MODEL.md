# Security Model: OAuth 2.0 Client Credentials Flow

This document explains the security model used by the Orders API and the benefits of OAuth 2.0 Client Credentials flow for machine-to-machine authentication.

## Table of Contents
- [Overview](#overview)
- [Current Implementation](#current-implementation)
- [Security Benefits](#security-benefits)
- [Current Limitations](#current-limitations)
- [Planned Enhancements](#planned-enhancements)
- [Security Best Practices](#security-best-practices)

---

## Overview

The Orders API uses **OAuth 2.0 Client Credentials Grant** for machine-to-machine (M2M) authentication. This is the industry-standard approach for service-to-service communication where no user interaction is involved.

### Authentication Flow

```
┌─────────┐                                  ┌─────────────┐
│ Client  │                                  │   Cognito   │
│ Service │                                  │  (OAuth AS) │
└────┬────┘                                  └──────┬──────┘
     │                                              │
     │  1. POST /oauth2/token                       │
     │     Authorization: Basic {client_id:secret}  │
     │     grant_type=client_credentials            │
     ├─────────────────────────────────────────────>│
     │                                              │
     │  2. Response: access_token (JWT)             │
     │     expires_in: 3600                         │
     │<─────────────────────────────────────────────┤
     │                                              │


┌────┴────┐                                  ┌──────────────┐
│ Client  │                                  │ API Gateway  │
│ Service │                                  │   + Lambda   │
└────┬────┘                                  └──────┬───────┘
     │                                              │
     │  3. GET /orders                              │
     │     Authorization: Bearer {access_token}     │
     │     x-api-key: {api_key}                     │
     ├─────────────────────────────────────────────>│
     │                                              │
     │                                              │  4. Validate JWT
     │                                              │     - Verify signature
     │                                              │     - Check expiration
     │                                              │     - Validate issuer
     │                                              │
     │  5. Response: Order data                     │
     │<─────────────────────────────────────────────┤
     │                                              │
```

---

## Current Implementation

### Components

1. **AWS Cognito User Pool**
   - Issues Client ID and Client Secret to each client
   - Provides OAuth 2.0 token endpoint
   - Issues JWT access tokens with 1-hour expiration

2. **API Gateway with Lambda Authorizer**
   - Validates JWT signature using Cognito JWKS
   - Verifies token claims (issuer, expiration, token_use)
   - Caches authorization decisions (5-minute TTL)

3. **API Keys**
   - Additional layer for client identification
   - Enables rate limiting and usage tracking
   - Required for all `/orders` endpoints

4. **Multi-Provider Support**
   - Lambda Authorizer supports Cognito and Azure AD
   - Extensible to Okta and other OIDC providers
   - Provider configuration via environment variables

---

## Security Benefits

### 1. Token-Based Authentication with Expiration

**How It Works:**
```bash
# Step 1: Exchange credentials for token (happens rarely)
curl -u "CLIENT_ID:SECRET" https://cognito.../oauth2/token
# Returns: access_token (valid for 1 hour)

# Step 2: Use token for API calls (credentials not transmitted)
curl -H "Authorization: Bearer TOKEN" https://api.../orders
```

**Benefits:**
- ✅ Client credentials transmitted only when obtaining new tokens
- ✅ Access tokens automatically expire (1 hour by default)
- ✅ Limited exposure window if token is compromised
- ✅ Can implement short-lived tokens (5-15 minutes) with automatic refresh

**Security Impact:**
- If a token is intercepted, attacker has access only until expiration
- Credentials themselves are rarely transmitted over the network
- Automatic expiration limits damage from token compromise

### 2. Separation of Authentication and Authorization

**How It Works:**
```javascript
// Token contains scopes defining permissions
{
  "sub": "client-id",
  "scope": "orders.read orders.write",
  "iss": "https://cognito...",
  "exp": 1633024800
}
```

**Benefits:**
- ✅ Client credentials prove identity (authentication)
- ✅ Token scopes define permissions (authorization)
- ✅ Different clients can have different permissions
- ✅ Can revoke specific permissions without changing credentials

**Example Use Cases:**
```
Client A: scope = "orders.read"              → Read-only access
Client B: scope = "orders.read orders.write" → Full access
Client C: scope = "orders.admin"             → Admin operations
```

### 3. Centralized Token Validation

**How It Works:**
```javascript
// Token is cryptographically signed
// Services validate using public keys from JWKS endpoint
// No database lookup needed

// Lambda Authorizer validates once:
const jwks = await fetch('https://cognito.../.well-known/jwks.json');
const verified = jwt.verify(token, jwks);

// Lambda receives pre-validated request
// No authentication code needed in business logic
```

**Benefits:**
- ✅ Token validated once at API Gateway (Lambda Authorizer)
- ✅ Cryptographic signature verification (no database lookup)
- ✅ Business logic layer receives pre-authenticated requests
- ✅ Reduced latency and database load
- ✅ Authorizer caches validation results (5 minutes)

**Performance Impact:**
- Signature verification: ~1ms
- Caching reduces repeated validations
- Scalable validation without database bottlenecks

### 4. Auditability and Monitoring

**How It Works:**
```bash
# Every token issuance is logged in Cognito
{
  "eventTime": "2025-10-06T10:30:00Z",
  "eventType": "TokenIssuance",
  "clientId": "acme-corp",
  "tokenExpiresIn": 3600,
  "sourceIP": "203.0.113.45"
}
```

**Benefits:**
- ✅ Complete audit trail of token issuance
- ✅ Track: when tokens issued, how often, from where
- ✅ Detect anomalies (e.g., unusual token request patterns)
- ✅ Identify potential credential compromise
- ✅ CloudWatch metrics and alarms for monitoring

**Monitoring Capabilities:**
- Alert if client requests tokens from multiple IPs simultaneously
- Alert if token request rate exceeds normal pattern
- Track API usage per client using API keys
- Audit trail for compliance requirements

### 5. Token Revocation Without Credential Change

**How It Works:**
```bash
# Scenario: Need to revoke client access

# Option 1: Revoke tokens (immediate)
aws cognito-idp admin-user-global-sign-out --user-pool-id <pool> --username <client>

# Option 2: Disable client (keeps credentials for later re-enable)
aws cognito-idp update-user-pool-client --enabled false

# Option 3: Delete client entirely
terraform destroy -target=aws_cognito_user_pool_client.client

# New tokens cannot be issued, existing tokens expire naturally (1 hour)
```

**Benefits:**
- ✅ Immediate revocation without changing credentials
- ✅ Temporary disable during investigation
- ✅ Re-enable client without credential redistribution
- ✅ Graceful degradation (existing tokens expire)

**Revocation Scenarios:**
- Suspected compromise → Revoke tokens immediately
- Temporary suspension → Disable client (reversible)
- Permanent removal → Delete client entirely
- Investigation → Disable temporarily, re-enable after review

### 6. Credential Rotation Support

**Current Support:**
```bash
# Rotate client secret
aws cognito-idp update-user-pool-client --client-id <id>
```

**Planned Enhancement:**
```bash
# Client can have multiple active secrets
aws cognito-idp create-user-pool-client-secret --client-id <client>
# Returns: new_secret (both old and new secrets work)

# After clients migrate to new secret:
aws cognito-idp delete-user-pool-client-secret --client-id <client> --secret-id <old>
```

**Benefits:**
- ✅ Zero-downtime credential rotation
- ✅ Multiple active secrets per client (transition period)
- ✅ Automated rotation schedule (e.g., every 90 days)
- ✅ Gradual migration without coordination

### 7. Multi-Provider Flexibility

**How It Works:**
```javascript
// Lambda Authorizer supports multiple providers
const PROVIDER_TYPE = process.env.PROVIDER_TYPE; // 'cognito', 'azure', 'okta'

// Same client integration works across providers
// Only Lambda Authorizer configuration changes
```

**Benefits:**
- ✅ Switch identity providers without client changes
- ✅ Support multiple providers simultaneously (Azure AD + Cognito)
- ✅ Enterprise SSO integration (Okta, Azure AD)
- ✅ Hybrid cloud scenarios

**Migration Example:**
```
Week 1: Cognito only
Week 2: Cognito + Azure AD (both work)
Week 3: Azure AD only (Cognito deprecated)
```

### 8. Industry Standard and Ecosystem

**OAuth 2.0 Advantages:**
- ✅ Industry standard protocol (RFC 6749)
- ✅ Client developers already familiar with OAuth
- ✅ Libraries available in all languages (Python, Node.js, Java, .NET)
- ✅ Built-in support in API gateways and service meshes
- ✅ Compatible with modern security tools (WAF, API gateways)
- ✅ Extensive tooling and ecosystem support

**Available Libraries:**
- Python: `requests-oauthlib`, `authlib`
- Node.js: `axios`, `client-oauth2`
- Java: Spring Security OAuth
- .NET: IdentityModel

---

## Current Limitations

While our implementation provides the foundation for OAuth security, we have some areas for enhancement:

### 1. ❌ No Scope-Based Authorization
**Current State:**
- All clients get full API access
- Cannot grant read-only or limited permissions
- Token provides all-or-nothing access

**Planned Enhancement:**
- Define resource server with scopes (`orders.read`, `orders.write`, `orders.admin`)
- Grant different scopes to different clients
- Enforce scopes in Lambda Authorizer and application layer

### 2. ❌ No Automated Credential Rotation
**Current State:**
- Client Secret set once during creation
- Manual rotation requires client updates
- No support for multiple active secrets

**Planned Enhancement:**
- Support multiple active secrets per client
- Automated rotation schedule (90-day lifecycle)
- Grace period for migration

### 3. ❌ Basic Rate Limiting
**Current State:**
- API keys configured but no usage plans
- No per-client rate limits
- No quota enforcement

**Planned Enhancement:**
- Usage plans with rate limiting (e.g., 100 req/sec)
- Daily/monthly quotas per client
- Burst limit protection

---

## Planned Enhancements

### Phase 1: Scope-Based Authorization ✅ Planned

**Implementation:**
1. Define Cognito Resource Server with scopes
2. Update Lambda Authorizer to validate scopes
3. Add scope enforcement in application layer
4. Update client provisioning to specify scopes

**Benefit:** Fine-grained permissions per client

**Example:**
```hcl
resource "aws_cognito_resource_server" "api" {
  identifier = "orders-api"
  name       = "Orders API"

  scope {
    scope_name        = "orders.read"
    scope_description = "Read orders"
  }

  scope {
    scope_name        = "orders.write"
    scope_description = "Create/update orders"
  }
}
```

### Phase 2: Credential Rotation ✅ Planned

**Implementation:**
1. Enable multiple client secrets per client
2. Implement rotation automation (Terraform + Lambda)
3. Add notification system for rotation events
4. Create rotation runbook for clients

**Benefit:** Zero-downtime credential rotation

**Rotation Flow:**
```
Day 0:  Issue new secret (both old and new work)
Day 1:  Notify client team
Day 30: Client migrates to new secret
Day 31: Delete old secret
```

### Phase 3: Rate Limiting & Quotas ✅ Planned

**Implementation:**
1. Create API Gateway Usage Plans per client
2. Define rate limits (requests per second)
3. Define quotas (requests per day/month)
4. Add throttling alerts and metrics

**Benefit:** Protect API from abuse and ensure fair usage

**Example Configuration:**
```hcl
resource "aws_api_gateway_usage_plan" "client_plan" {
  throttle_settings {
    rate_limit  = 100  # requests per second
    burst_limit = 200
  }

  quota_settings {
    limit  = 10000  # requests per day
    period = "DAY"
  }
}
```

### Phase 4: Enhanced Monitoring (Future)

**Ideas:**
- Anomaly detection for token requests
- Geographic access patterns
- Client behavior baselines
- Automated security alerts

---

## Security Best Practices

### For Platform Team

1. **Token Configuration**
   - Keep token TTL short (1 hour or less)
   - Use JWT for stateless validation
   - Enable token caching in authorizer (5 minutes)

2. **Client Management**
   - Use separate clients per service/team
   - Grant minimal required scopes
   - Regular access reviews (quarterly)

3. **Monitoring**
   - CloudWatch alarms for authentication failures
   - Track token issuance rates
   - Review audit logs weekly

4. **Secrets Management**
   - Never log client secrets
   - Store in AWS Secrets Manager
   - Rotate credentials quarterly

### For Client Teams

1. **Credential Storage**
   - Use environment variables (dev/test)
   - Use secret management tools (production)
   - Never hardcode credentials

2. **Token Handling**
   - Cache tokens until expiration
   - Implement automatic refresh
   - Add 60-second buffer before expiry

3. **Error Handling**
   - Retry with exponential backoff
   - Handle 401 by refreshing token
   - Alert on persistent failures

4. **Security**
   - Use HTTPS only
   - Validate server certificates
   - Log authentication errors (not tokens)

---

## Conclusion

### Current Implementation Value

Our OAuth 2.0 Client Credentials implementation provides:

**Core Security Features:**
- ✅ Token-based authentication with automatic expiration
- ✅ Centralized validation at API Gateway
- ✅ Complete audit trail of authentication events
- ✅ Flexible token revocation mechanisms
- ✅ Multi-provider support (Cognito, Azure AD, Okta)

**Operational Benefits:**
- ✅ Reduced attack surface (credentials rarely transmitted)
- ✅ Scalable validation without database bottlenecks
- ✅ Standard OAuth 2.0 protocol (ecosystem support)
- ✅ Foundation for future security enhancements

### With Planned Enhancements

Once we implement scopes, rotation, and rate limiting, we'll have:

- **Enterprise-grade security** comparable to major SaaS platforms
- **Defense-in-depth** with multiple security layers
- **Operational excellence** with zero-downtime operations
- **Compliance-ready** with full audit trails
- **Fine-grained access control** with scope-based permissions

### Why This Architecture?

1. **Security First**: Token expiration and revocation minimize breach impact
2. **Performance**: Cryptographic validation scales better than database lookups
3. **Flexibility**: Multi-provider support and extensible to additional OAuth providers
4. **Standards**: OAuth 2.0 is proven, well-understood, and widely supported
5. **Future-Proof**: Foundation for advanced features (scopes, rotation, monitoring)

---

**Last Updated:** 2025-10-06
**Next Review:** After Phase 1 (Scope-Based Authorization) implementation
