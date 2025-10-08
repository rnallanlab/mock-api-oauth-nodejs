# Future Enhancements

This directory contains **ready-to-use code** for future enhancements that are **not currently deployed** to AWS.

## Available Enhancements

### 1. GitHub Actions CI/CD (`github-actions-cicd/`)

Automated Terraform deployments from GitHub Actions with remote state management.

**Features:**
- Remote state in S3 (shared across team)
- State locking with DynamoDB
- OIDC authentication (no AWS keys in GitHub)
- Automated deployments on push to main
- PR plan comments for review

**Status:** ✅ Documentation Complete | ❌ Not Implemented

**When to Deploy:**
- Team collaboration (multiple developers)
- Automated deployments
- Production environments
- Need audit trail and approval workflows

**How to Deploy:**
1. Create S3 bucket and DynamoDB table for state
2. Configure backend in `terraform/backend.tf`
3. Set up AWS OIDC provider and IAM role
4. Add GitHub Actions workflow
5. Configure GitHub secrets

**Documentation:** `github-actions-cicd/README.md`

**Cost:** ~$0.02/month (S3 + DynamoDB)

---

### 2. Secret Rotation (`secret-rotation/`)

Automated credential rotation with EventBridge (no database required).

**Features:**
- 90-day rotation cycle (configurable)
- 14-day advance warning
- Email notifications via SNS
- Automatic rescheduling
- No DynamoDB - uses EventBridge rules

**Status:** ✅ Code Complete | ❌ Not Deployed

**When to Deploy:**
- Moving to production
- Managing multiple clients (>5)
- Need automated credential lifecycle

**How to Deploy:**
1. Copy `secret-rotation/` to `terraform/modules/`
2. Add module to `terraform/main.tf`:
   ```hcl
   module "secret_rotation" {
     source = "./modules/secret-rotation"

     environment            = var.environment
     cognito_user_pool_id   = module.cognito.user_pool_id
     cognito_user_pool_arn  = module.cognito.user_pool_arn
     notification_email     = "platform-team@example.com"
   }
   ```
3. Run `terraform apply`
4. Confirm SNS email subscription

**Documentation:** `secret-rotation/CREDENTIAL-ROTATION.md`

**Cost:** ~$0.05/month for 10 clients

---

### 3. Scope-Based Authorization (Coming Soon)

Fine-grained OAuth permissions using Cognito Resource Server.

**Planned Features:**
- OAuth scopes (e.g., `orders.read`, `orders.write`, `orders.admin`)
- Different client tiers with different permissions
- Scope validation in Lambda Authorizer
- Application-layer scope enforcement

**Status:** ⏳ Planned | ❌ Not Started

---

## Why Not Deployed?

These enhancements are **code-ready** but kept separate because:

1. **POC Simplicity** - Current implementation is minimal and sufficient for proof-of-concept
2. **Cost Control** - No need for additional AWS resources during POC
3. **Learning Curve** - Easier to understand core architecture without extras
4. **Future Flexibility** - Can deploy when actually needed

## When to Enable

### GitHub Actions CI/CD
**Deploy when:**
- ✅ Team has multiple developers
- ✅ Need automated deployments
- ✅ Want PR review workflow
- ✅ Moving to production
- ✅ Need deployment audit trail

**Skip if:**
- ❌ Solo developer
- ❌ POC/demo only
- ❌ Prefer manual deployments

### Credential Rotation
**Deploy when:**
- ✅ Moving to production
- ✅ Compliance requires rotation (e.g., SOC2, PCI-DSS)
- ✅ Managing >5 active clients
- ✅ Want automated credential lifecycle

**Skip if:**
- ❌ POC/demo only
- ❌ Short-lived project
- ❌ Manual rotation is acceptable

### Scope-Based Authorization
**Deploy when:**
- ✅ Need fine-grained permissions (read-only vs full access)
- ✅ Different client tiers
- ✅ Compliance requires least-privilege access

**Skip if:**
- ❌ All clients need same access level
- ❌ POC/demo only

## Integration Guide

Each enhancement includes:
- ✅ Complete Terraform module
- ✅ Lambda functions (if needed)
- ✅ Scripts for management
- ✅ Comprehensive documentation
- ✅ Cost estimates

Simply follow the "How to Deploy" instructions in each subdirectory.

---

**Last Updated:** 2025-10-06
