# GitHub Actions CI/CD for Terraform

Complete guide for running Terraform deployments from GitHub Actions instead of local machine.

## Table of Contents
- [Overview](#overview)
- [Current vs CI/CD Setup](#current-vs-cicd-setup)
- [Terraform State Management](#terraform-state-management)
- [Implementation Steps](#implementation-steps)
- [GitHub Actions Workflow](#github-actions-workflow)
- [AWS IAM Setup (OIDC)](#aws-iam-setup-oidc)
- [Configuration Files](#configuration-files)
- [Testing & Verification](#testing--verification)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Overview

This guide shows how to automate Terraform deployments using GitHub Actions with:
- ✅ **Remote state** in AWS S3 (shared across team/CI)
- ✅ **State locking** with DynamoDB (prevent conflicts)
- ✅ **OIDC authentication** (no AWS access keys in GitHub)
- ✅ **Automated deployments** on push to main
- ✅ **PR plan comments** for review before merge

## Current vs CI/CD Setup

### Current Setup (Local Execution)

```
Developer Laptop
  ├── terraform.tfstate (LOCAL - not shared!)
  ├── .terraform/ (plugins/modules)
  └── Run: terraform apply
```

**Problems:**
- ❌ State file on laptop (team can't collaborate)
- ❌ No automation (manual deployments)
- ❌ No audit trail
- ❌ Risk of concurrent changes

### CI/CD Setup (GitHub Actions)

```
GitHub Actions
  ├── Pulls code from repo
  ├── Builds Lambda JAR
  ├── Runs terraform plan/apply
  └── State stored in AWS S3

AWS S3
  ├── terraform.tfstate (SHARED state)
  └── Versioning enabled (rollback capability)

DynamoDB
  └── State locks (prevent concurrent runs)
```

**Benefits:**
- ✅ Shared state (team collaboration)
- ✅ Automated deployments
- ✅ Complete audit trail
- ✅ Safe concurrent operations
- ✅ No credentials in GitHub

---

## Terraform State Management

### What is Terraform State?

Terraform state tracks what resources exist in AWS. It's a JSON file containing:

```json
{
  "version": 4,
  "terraform_version": "1.5.0",
  "resources": [
    {
      "type": "aws_lambda_function",
      "name": "orders_api",
      "instances": [{
        "attributes": {
          "arn": "arn:aws:lambda:us-east-1:123:function:orders-api-dev",
          "function_name": "orders-api-dev",
          "handler": "io.micronaut.function.aws.proxy.MicronautLambdaHandler",
          "memory_size": 512,
          "timeout": 30
        }
      }]
    }
  ]
}
```

### How Terraform Uses State

**On every `terraform plan` or `apply`:**

1. **Read state file** → Know what Terraform thinks exists
2. **Query AWS APIs** → Know what actually exists
3. **Compare with .tf files** → Know what you want
4. **Calculate diff** → Determine changes needed

**Example - Drift Detection:**
```bash
terraform plan

# Output:
# aws_lambda_function.main:
#   ~ timeout: 30 → 60 (changed outside Terraform)
#   + environment variables added manually
```

### Terraform vs CloudFormation

| Feature | Terraform | CloudFormation |
|---------|-----------|----------------|
| **State Storage** | S3 (manual setup required) | AWS (automatic) |
| **State Locking** | DynamoDB (manual setup) | AWS (automatic) |
| **Drift Detection** | `terraform plan` | Drift detection feature |
| **Multi-Cloud** | ✅ AWS, Azure, GCP, etc. | ❌ AWS only |
| **Local State** | ⚠️ Possible (not for teams) | ❌ Not possible |
| **State Versioning** | S3 versioning | Automatic |

### Remote State Backend

**Why S3 + DynamoDB?**

- **S3:** Stores state file (durable, versioned, encrypted)
- **DynamoDB:** State locking (prevents concurrent modifications)

**Example Scenario:**
```
Developer runs:    terraform apply
GitHub Actions runs: terraform apply  (at same time)

Without locking: ❌ Corruption, conflicts, lost changes
With locking:    ✅ One waits for the other to finish
```

---

## Implementation Steps

### Step 1: Create S3 Bucket for State

**One-time setup (run locally):**

```bash
# 1. Create S3 bucket
aws s3api create-bucket \
  --bucket orders-api-terraform-state \
  --region us-east-1

# 2. Enable versioning (rollback capability)
aws s3api put-bucket-versioning \
  --bucket orders-api-terraform-state \
  --versioning-configuration Status=Enabled

# 3. Enable encryption
aws s3api put-bucket-encryption \
  --bucket orders-api-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# 4. Block public access
aws s3api put-public-access-block \
  --bucket orders-api-terraform-state \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# 5. Enable lifecycle policy (optional - keep old versions for 30 days)
aws s3api put-bucket-lifecycle-configuration \
  --bucket orders-api-terraform-state \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 30
      }
    }]
  }'
```

### Step 2: Create DynamoDB Table for Locking

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 \
  --tags Key=Project,Value=orders-api Key=ManagedBy,Value=Terraform
```

**Lock table structure:**
- **LockID (Hash Key):** `bucket-name/path/to/terraform.tfstate-md5`
- **Attributes:** Who, When, Operation (plan/apply)

### Step 3: Configure Remote Backend

Create `terraform/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "orders-api-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Step 4: Migrate Local State to S3

```bash
cd terraform

# Initialize with new backend
terraform init -migrate-state

# Terraform will ask: "Do you want to copy existing state to the new backend?"
# Answer: yes

# Verify migration
aws s3 ls s3://orders-api-terraform-state/dev/
# Output: terraform.tfstate

# Local state should be removed
ls terraform.tfstate
# Output: No such file or directory
```

### Step 5: Set Up GitHub OIDC Authentication

**Why OIDC?**
- ✅ No AWS access keys stored in GitHub
- ✅ Temporary credentials (auto-expire)
- ✅ Audit trail (who accessed from GitHub)
- ✅ Fine-grained permissions per repo

**Create OIDC Provider (one-time for AWS account):**

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Create IAM Trust Policy:**

```bash
cat > github-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:rnallanlab/api-aws-oauth-client-credentials-poc:*"
        }
      }
    }
  ]
}
EOF

# Replace YOUR_ACCOUNT_ID with your AWS account ID
sed -i '' "s/YOUR_ACCOUNT_ID/$(aws sts get-caller-identity --query Account --output text)/g" github-trust-policy.json
```

**Create IAM Role:**

```bash
# Create role
aws iam create-role \
  --role-name GitHubActionsRole \
  --assume-role-policy-document file://github-trust-policy.json \
  --description "Role for GitHub Actions to deploy Terraform"

# Option 1: Use AWS managed policy (PowerUserAccess)
aws iam attach-role-policy \
  --role-name GitHubActionsRole \
  --policy-arn arn:aws:iam::aws:policy/PowerUserAccess

# Option 2: Create minimal custom policy (recommended for production)
cat > terraform-permissions.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "lambda:*",
        "apigateway:*",
        "cognito-idp:*",
        "iam:GetRole",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PassRole",
        "logs:*",
        "s3:GetObject",
        "s3:PutObject",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name GitHubActionsRole \
  --policy-name TerraformPermissions \
  --policy-document file://terraform-permissions.json
```

### Step 6: Configure GitHub Repository

**Add Secrets (Settings → Secrets and variables → Actions):**

```
Name: AWS_ACCOUNT_ID
Value: <your-aws-account-id>
```

**Get your account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```

---

## GitHub Actions Workflow

Create `.github/workflows/terraform.yml`:

```yaml
name: Terraform CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'server/**'
      - '.github/workflows/terraform.yml'
  pull_request:
    branches: [main]
    paths:
      - 'terraform/**'
      - 'server/**'
  workflow_dispatch:  # Manual trigger

env:
  AWS_REGION: us-east-1
  TERRAFORM_VERSION: 1.5.0

jobs:
  terraform:
    name: Terraform Plan & Apply
    runs-on: ubuntu-latest

    permissions:
      id-token: write      # Required for OIDC
      contents: read       # Required to checkout code
      pull-requests: write # Required to comment on PRs

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Setup Java 21
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'
          cache: 'maven'

      - name: Build Lambda JAR
        run: |
          cd server
          mvn clean package -DskipTests
          echo "✅ Lambda JAR built successfully"
          ls -lh target/*.jar

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/GitHubActionsRole
          aws-region: ${{ env.AWS_REGION }}

      - name: Verify AWS Identity
        run: |
          echo "AWS Identity:"
          aws sts get-caller-identity

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TERRAFORM_VERSION }}

      - name: Terraform Format Check
        run: |
          cd terraform
          terraform fmt -check -recursive
        continue-on-error: true

      - name: Terraform Init
        run: |
          cd terraform
          terraform init

      - name: Terraform Validate
        run: |
          cd terraform
          terraform validate

      - name: Terraform Plan
        id: plan
        run: |
          cd terraform
          terraform plan -out=tfplan -no-color
        continue-on-error: true

      - name: Comment PR with Plan
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const planOutput = `${{ steps.plan.outputs.stdout }}`;

            const output = `#### Terraform Plan 📖

            <details><summary>Show Plan Output</summary>

            \`\`\`hcl
            ${planOutput}
            \`\`\`

            </details>

            **Plan Status:** ${{ steps.plan.outcome }}
            *Triggered by: @${{ github.actor }}*
            *Action: \`${{ github.event_name }}\`*`;

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: output
            });

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          cd terraform
          terraform apply -auto-approve tfplan
          echo "✅ Terraform apply completed successfully"

      - name: Output Deployment Info
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          cd terraform
          echo "📋 Deployment Outputs:"
          terraform output -json | jq

      - name: Upload Terraform Plan (Artifact)
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: terraform-plan
          path: terraform/tfplan
          retention-days: 7
```

### Workflow Explanation

**Triggers:**
- `push` to main → Plan & Apply
- `pull_request` → Plan only (comment on PR)
- `workflow_dispatch` → Manual trigger

**Steps:**
1. **Checkout Code** - Get latest code from repo
2. **Setup Java** - Install Java 21 for building Lambda
3. **Build Lambda** - Compile JAR file
4. **AWS OIDC Auth** - Get temporary AWS credentials
5. **Terraform Init** - Download providers, connect to S3 backend
6. **Terraform Plan** - Calculate changes
7. **Comment PR** - Show plan on pull request (if PR)
8. **Terraform Apply** - Apply changes (if main branch)

**Security Features:**
- ✅ OIDC authentication (no static credentials)
- ✅ Minimal IAM permissions
- ✅ Plan review before apply (via PR)
- ✅ Audit trail in GitHub Actions logs

---

## Configuration Files

### Backend Configuration (per Environment)

**Option A: Single backend with workspaces**

`terraform/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket               = "orders-api-terraform-state"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
    encrypt              = true
    dynamodb_table       = "terraform-state-lock"
    workspace_key_prefix = "env"  # Creates: env/dev/, env/staging/, env/prod/
  }
}
```

**Option B: Separate backend per environment**

`terraform/environments/dev/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "orders-api-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

`terraform/environments/prod/backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "orders-api-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Enhanced Workflow (Multi-Environment)

```yaml
name: Terraform Multi-Environment

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  dev-deploy:
    name: Deploy to Dev
    runs-on: ubuntu-latest
    environment: dev  # GitHub Environment protection
    steps:
      # ... (same steps as above)
      - name: Terraform Init (Dev)
        run: |
          cd terraform/environments/dev
          terraform init

  prod-deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    environment: production  # Requires manual approval
    needs: dev-deploy
    if: github.ref == 'refs/heads/main'
    steps:
      # ... (same steps for prod)
```

---

## Testing & Verification

### Step 1: Test Local to Remote Migration

```bash
# After setting up backend, test locally
cd terraform
terraform plan

# Should show: "Acquiring state lock. This may take a few moments..."
# Verify lock in DynamoDB
aws dynamodb scan --table-name terraform-state-lock

# Check state in S3
aws s3 ls s3://orders-api-terraform-state/dev/
```

### Step 2: Test GitHub Actions Workflow

**Create a test PR:**
```bash
git checkout -b test-cicd
echo "# Test" >> README.md
git add .
git commit -m "Test: Trigger GitHub Actions"
git push origin test-cicd

# Create PR on GitHub
# Check: Actions tab → Should see "Terraform CI/CD" running
# Check: PR comments → Should see Terraform plan
```

**Merge to main:**
```bash
# Merge PR via GitHub UI
# Check: Actions tab → Should run plan AND apply
# Check: AWS → Resources should be deployed
```

### Step 3: Verify State Locking

**Simulate concurrent runs:**
```bash
# Terminal 1: Run locally
cd terraform
terraform apply &

# Terminal 2: Immediately run again
terraform apply

# Expected: One gets lock, other waits
# Output: "Error acquiring the state lock"
```

### Step 4: Test State Rollback

**If deployment fails, rollback to previous state:**
```bash
# List state versions
aws s3api list-object-versions \
  --bucket orders-api-terraform-state \
  --prefix dev/terraform.tfstate

# Restore previous version
aws s3api get-object \
  --bucket orders-api-terraform-state \
  --key dev/terraform.tfstate \
  --version-id <version-id> \
  terraform.tfstate.backup

# Copy backup to S3
aws s3 cp terraform.tfstate.backup \
  s3://orders-api-terraform-state/dev/terraform.tfstate
```

---

## Troubleshooting

### Issue 1: State Lock Timeout

**Error:**
```
Error acquiring the state lock
Lock Info:
  ID:        abc-123
  Path:      orders-api-terraform-state/dev/terraform.tfstate
  Operation: OperationTypeApply
  Who:       github-actions
  Created:   2025-10-06 10:00:00
```

**Cause:** Previous run didn't release lock (crashed, canceled)

**Solution:**
```bash
# Force unlock (use Lock ID from error)
terraform force-unlock abc-123

# Or delete lock from DynamoDB
aws dynamodb delete-item \
  --table-name terraform-state-lock \
  --key '{"LockID": {"S": "orders-api-terraform-state/dev/terraform.tfstate-md5"}}'
```

### Issue 2: OIDC Authentication Failed

**Error:**
```
Error: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**Check:**
```bash
# 1. Verify OIDC provider exists
aws iam list-open-id-connect-providers

# 2. Verify IAM role trust policy
aws iam get-role --role-name GitHubActionsRole --query 'Role.AssumeRolePolicyDocument'

# 3. Check GitHub repo name matches trust policy
# Trust policy should have: "repo:rnallanlab/api-aws-oauth-client-credentials-poc:*"
```

**Fix:** Update trust policy with correct repo name

### Issue 3: State Corruption

**Error:**
```
Error loading state: state snapshot was created by Terraform v1.6.0,
which is newer than current v1.5.0
```

**Solution:**
```bash
# Option 1: Upgrade Terraform version
terraform version  # Check current
# Update terraform_version in GitHub Actions workflow

# Option 2: Restore from S3 version history
aws s3api list-object-versions \
  --bucket orders-api-terraform-state \
  --prefix dev/terraform.tfstate \
  --query 'Versions[?IsLatest==`false`].[VersionId,LastModified]' \
  --output table

# Restore specific version
aws s3api get-object \
  --bucket orders-api-terraform-state \
  --key dev/terraform.tfstate \
  --version-id <older-version-id> \
  terraform.tfstate
```

### Issue 4: Drift Detected

**GitHub Actions shows changes you didn't make:**
```
# aws_lambda_function.main:
  ~ timeout: 30 → 60 (changed outside Terraform)
```

**Cause:** Someone changed resources in AWS Console

**Solutions:**

**Option A: Import changes to Terraform**
```hcl
# Update .tf file to match AWS
resource "aws_lambda_function" "main" {
  timeout = 60  # Match what's in AWS
}
```

**Option B: Revert AWS to match Terraform**
```bash
terraform apply  # Will change AWS back to timeout=30
```

---

## Best Practices

### 1. State Management

✅ **DO:**
- Use remote state for all non-local environments
- Enable S3 versioning (rollback capability)
- Encrypt state at rest (AES256 or KMS)
- Use DynamoDB for state locking
- Separate state per environment (dev/staging/prod)

❌ **DON'T:**
- Commit state files to git
- Use local state for team/CI environments
- Manually edit state files
- Share state files via email/Slack

### 2. Security

✅ **DO:**
- Use OIDC for GitHub authentication (no static keys)
- Principle of least privilege for IAM roles
- Enable audit logging (CloudTrail)
- Use GitHub Environments with approval gates
- Rotate credentials regularly (even with OIDC)

❌ **DON'T:**
- Store AWS access keys in GitHub secrets
- Use admin-level permissions
- Allow public access to state bucket
- Skip state encryption

### 3. Workflow

✅ **DO:**
- Run `terraform plan` on every PR
- Comment plan output on PRs
- Require manual approval for production
- Use consistent naming (environments, backends)
- Tag all resources for cost tracking

❌ **DON'T:**
- Auto-apply on every commit without review
- Skip validation steps
- Deploy directly to production
- Mix manual and automated changes

### 4. State File Hygiene

✅ **DO:**
```bash
# Regularly check state health
terraform state list

# Validate state integrity
terraform validate

# Refresh state (compare with AWS)
terraform refresh
```

❌ **DON'T:**
```bash
# Never manually edit state
vim terraform.tfstate  # ❌

# Never delete state without backup
rm terraform.tfstate  # ❌
```

### 5. Multi-Environment Strategy

**Recommended Structure:**
```
terraform/
├── backend.tf              # S3 backend config
├── main.tf                 # Root module
├── environments/
│   ├── dev/
│   │   ├── main.tf        # Dev-specific config
│   │   └── terraform.tfvars
│   ├── staging/
│   └── prod/
└── modules/                # Shared modules
```

**Workflow:**
```yaml
# .github/workflows/terraform-dev.yml
on:
  push:
    branches: [develop]

# .github/workflows/terraform-prod.yml
on:
  push:
    branches: [main]
```

---

## Migration Checklist

- [ ] **Step 1:** Create S3 bucket for state
- [ ] **Step 2:** Create DynamoDB table for locking
- [ ] **Step 3:** Configure backend.tf in Terraform
- [ ] **Step 4:** Run `terraform init -migrate-state` locally
- [ ] **Step 5:** Verify state in S3
- [ ] **Step 6:** Create GitHub OIDC provider in AWS
- [ ] **Step 7:** Create IAM role with trust policy
- [ ] **Step 8:** Add AWS_ACCOUNT_ID to GitHub secrets
- [ ] **Step 9:** Create `.github/workflows/terraform.yml`
- [ ] **Step 10:** Test with PR (plan only)
- [ ] **Step 11:** Test merge to main (plan + apply)
- [ ] **Step 12:** Document for team

---

## Cost Breakdown

### Remote State Infrastructure

| Resource | Usage | Cost/Month |
|----------|-------|------------|
| **S3 Bucket** | ~100 KB state file | ~$0.002 |
| **S3 Requests** | ~100 requests/month | ~$0.001 |
| **S3 Versioning** | ~10 versions × 100 KB | ~$0.020 |
| **DynamoDB** | Pay-per-request, ~50 requests/month | ~$0.001 |
| **GitHub Actions** | 2,000 minutes/month free | $0 |

**Total: ~$0.02/month** (essentially free)

### Scaling Costs

**For 10 environments (dev, staging, prod × regions):**
- S3: ~$0.20/month
- DynamoDB: ~$0.01/month
- GitHub Actions: Still free (under 2,000 min)

**Total: ~$0.21/month**

---

## Resources

### Official Documentation
- [Terraform S3 Backend](https://www.terraform.io/language/settings/backends/s3)
- [GitHub Actions AWS OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS IAM OIDC Provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html)

### Example Repositories
- [Terraform GitHub Actions Examples](https://github.com/hashicorp/setup-terraform)
- [AWS OIDC Examples](https://github.com/aws-actions/configure-aws-credentials)

### Tools
- [Terraform Cloud](https://app.terraform.io/) - Alternative to S3 backend (free for small teams)
- [Atlantis](https://www.runatlantis.io/) - Self-hosted Terraform automation
- [Terragrunt](https://terragrunt.gruntwork.io/) - Wrapper for managing multiple environments

---

**Last Updated:** 2025-10-06
**Status:** ✅ Documentation Complete | ❌ Not Implemented

**Ready to Deploy?** Follow the [Implementation Steps](#implementation-steps) to enable CI/CD for this project.
