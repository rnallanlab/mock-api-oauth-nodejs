# Deployment Guide

This guide provides detailed step-by-step instructions for deploying the Mock Orders API to AWS.

## 🎯 Prerequisites Checklist

Before starting, ensure you have:

- [ ] AWS Account with administrative access
- [ ] AWS CLI installed and configured (`aws configure`)
- [ ] Java 21 installed (`java -version`)
- [ ] Maven 3.8+ installed (`mvn -version`)
- [ ] Terraform 1.0+ installed (`terraform -version`)
- [ ] Git installed (optional, for version control)

## 📋 Deployment Options Comparison

| Feature | Lambda + API Gateway | ECS Fargate + ALB |
|---------|---------------------|-------------------|
| **Cold Start** | Yes (~2-5s for Java) | No |
| **Cost (Low Traffic)** | ~$5/month | ~$40/month |
| **Cost (High Traffic)** | Scales linearly | More cost-effective |
| **Maintenance** | Minimal | Moderate |
| **Deployment Speed** | Fast (~2 min) | Moderate (~5 min) |
| **Best For** | Mock/Test APIs, Sporadic traffic | Production APIs, Consistent traffic |

## 🚀 Lambda Deployment (Step-by-Step)

### Step 1: Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify configuration
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Step 2: Build the Application

```bash
# Navigate to project root
cd /path/to/mock-api-oauth-aws

# Build server and client
./scripts/build.sh

# Verify JARs were created
ls -lh server/target/mock-api-oauth-aws-1.0.0.jar
ls -lh client/target/orders-api-client-1.0.0.jar
```

Expected output:
```
-rw-r--r--  1 user  staff    15M Oct  1 12:30 server/target/mock-api-oauth-aws-1.0.0.jar
-rw-r--r--  1 user  staff     5M Oct  1 12:30 client/target/orders-api-client-1.0.0.jar
```

### Step 3: Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads AWS provider)
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 4: Review Terraform Plan

```bash
# Generate execution plan
terraform plan -var="deployment_type=lambda" -var="aws_region=us-east-1"
```

Review the output carefully. You should see resources being created:
- Cognito User Pool
- Cognito User Pool Client
- Lambda Function
- API Gateway REST API
- IAM Roles and Policies
- CloudWatch Log Groups

### Step 5: Deploy Infrastructure

```bash
# Apply Terraform configuration
terraform apply -var="deployment_type=lambda" -var="aws_region=us-east-1"

# Type 'yes' when prompted
```

⏱️ **Deployment time:** ~3-5 minutes

### Step 6: Capture Outputs

```bash
# Save outputs to file
terraform output > ../deployment-outputs.txt

# Display outputs
terraform output

# Get specific values
export API_ENDPOINT=$(terraform output -raw api_endpoint)
export USER_POOL_ID=$(terraform output -raw cognito_user_pool_id)
export CLIENT_ID=$(terraform output -raw cognito_client_id)
export CLIENT_SECRET=$(terraform output -raw cognito_client_secret)

echo "API Endpoint: $API_ENDPOINT"
echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
```

### Step 7: Get API Key

```bash
# Get API key value (needed for authenticated requests)
export API_KEY=$(terraform output -json api_key_values | jq -r '.["demo-client"]')

echo "API Key: $API_KEY"
```

### Step 8: Test Deployment

#### Option A: Using Client Credentials Flow (Recommended)

```bash
# Get Cognito domain
export COGNITO_DOMAIN=$(terraform output -raw cognito_user_pool_domain)

# Get access token using client credentials
export TOKEN_RESPONSE=$(curl -s -X POST \
  "https://${COGNITO_DOMAIN}.auth.us-east-1.amazoncognito.com/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -u "${CLIENT_ID}:${CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

export ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')

# Test health endpoint (no auth required)
curl -s "$API_ENDPOINT/health" | jq

# Test authenticated endpoint with JWT + API Key
curl -s "$API_ENDPOINT/orders?customerId=CUST12345&limit=5" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: $API_KEY" | jq
```

Expected response:
```json
{
  "orders": [...],
  "totalCount": 20,
  "limit": 5,
  "offset": 0
}
```

#### Option B: Using Test User (Optional)

If you want to test with user credentials instead:

```bash
# Create user with temporary password
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username testuser \
  --user-attributes Name=email,Value=testuser@example.com Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

# Set permanent password
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username testuser \
  --password "MySecurePass123!" \
  --permanent

# Get access token
export ACCESS_TOKEN=$(aws cognito-idp initiate-auth \
  --auth-flow USER_PASSWORD_AUTH \
  --client-id $CLIENT_ID \
  --auth-parameters USERNAME=testuser,PASSWORD=MySecurePass123! \
  --query 'AuthenticationResult.AccessToken' \
  --output text)

# Test with user token
curl -s "$API_ENDPOINT/orders?customerId=CUST12345" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "x-api-key: $API_KEY" | jq
```

### Step 9: Run Java Client Tests

```bash
# Navigate to client directory
cd ../client

# Build client
mvn clean package

# Run client tests
java -jar target/orders-api-client-1.0.0.jar \
  $API_ENDPOINT \
  us-east-1 \
  $USER_POOL_ID \
  $CLIENT_ID \
  $CLIENT_SECRET \
  testuser \
  MySecurePass123!
```

## 🐳 ECS Fargate Deployment (Step-by-Step)

### Step 1-2: Same as Lambda (Configure AWS + Build)

### Step 3: Create Dockerfile

```bash
cd /path/to/mock-api-oauth-aws

cat > Dockerfile << 'EOF'
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Copy the JAR file
COPY server/target/mock-api-oauth-aws-1.0.0.jar app.jar

# Expose port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
```

**Note:** You'll need to modify the Lambda handler to work as a standalone HTTP server.

### Step 4: Deploy Infrastructure with ECS

```bash
cd terraform

terraform init

terraform plan -var="deployment_type=ecs" -var="aws_region=us-east-1"

terraform apply -var="deployment_type=ecs" -var="aws_region=us-east-1"
```

### Step 5: Build and Push Docker Image

```bash
# Get ECR repository URL from Terraform
export ECR_REPO=$(terraform output -raw ecr_repository_url)
export AWS_REGION=$(terraform output -raw aws_region)

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO

# Build Docker image
docker build -t orders-api:latest .

# Tag image
docker tag orders-api:latest $ECR_REPO:latest

# Push image
docker push $ECR_REPO:latest
```

### Step 6: Update ECS Service

```bash
# Get cluster and service names
export CLUSTER_NAME=$(terraform output -raw ecs_cluster_name)

# Force new deployment
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service ${CLUSTER_NAME}-service \
  --force-new-deployment \
  --region $AWS_REGION

# Wait for deployment to complete
aws ecs wait services-stable \
  --cluster $CLUSTER_NAME \
  --services ${CLUSTER_NAME}-service \
  --region $AWS_REGION
```

### Step 7: Test ECS Deployment

```bash
# Get ALB endpoint
export ALB_ENDPOINT=$(terraform output -raw ecs_alb_endpoint)

# Test health endpoint
curl -s "$ALB_ENDPOINT/health" | jq

# Continue with Cognito user creation and testing as in Lambda deployment
```

## 🔧 Environment-Specific Deployments

### Development Environment

```bash
cd terraform

terraform workspace new dev
terraform workspace select dev

terraform apply \
  -var="deployment_type=lambda" \
  -var="environment=dev" \
  -var="aws_region=us-east-1"
```

### Production Environment

```bash
terraform workspace new prod
terraform workspace select prod

terraform apply \
  -var="deployment_type=ecs" \
  -var="environment=prod" \
  -var="aws_region=us-west-2" \
  -var="create_test_user=false"
```

## 📊 Monitoring and Logs

### View Lambda Logs

```bash
# Get function name
export FUNCTION_NAME=$(cd terraform && terraform output -raw lambda_function_name)

# Tail logs
aws logs tail /aws/lambda/$FUNCTION_NAME --follow
```

### View ECS Logs

```bash
# Get log group name
export LOG_GROUP="/ecs/orders-api-dev"

# Tail logs
aws logs tail $LOG_GROUP --follow
```

### View API Gateway Logs

```bash
aws logs tail /aws/apigateway/orders-api-dev --follow
```

## 🔄 Updating the Deployment

### Lambda Updates

```bash
# 1. Make code changes
# 2. Rebuild
./scripts/build.sh

# 3. Re-apply Terraform (will detect JAR change)
cd terraform
terraform apply -var="deployment_type=lambda"
```

### ECS Updates

```bash
# 1. Make code changes
# 2. Rebuild and push new image
./scripts/build.sh
docker build -t orders-api:latest .
docker tag orders-api:latest $ECR_REPO:latest
docker push $ECR_REPO:latest

# 3. Force new deployment
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service ${CLUSTER_NAME}-service \
  --force-new-deployment
```

## 🧹 Cleanup and Teardown

### Remove All Resources

```bash
cd terraform

# Review what will be destroyed
terraform plan -destroy -var="deployment_type=lambda"

# Destroy infrastructure
terraform destroy -var="deployment_type=lambda"

# Type 'yes' when prompted
```

⏱️ **Cleanup time:** ~2-3 minutes

### Verify Cleanup

```bash
# Check Lambda functions
aws lambda list-functions --query 'Functions[?contains(FunctionName, `orders-api`)].FunctionName'

# Check API Gateways
aws apigateway get-rest-apis --query 'items[?contains(name, `orders-api`)].name'

# Check Cognito User Pools
aws cognito-idp list-user-pools --max-results 10 --query 'UserPools[?contains(Name, `orders-api`)].Name'

# Check ECS Clusters
aws ecs list-clusters --query 'clusterArns[?contains(@, `orders-api`)]'
```

All commands should return empty arrays `[]`.

## ⚠️ Troubleshooting

### Issue: Terraform State Lock

**Error:** `Error acquiring the state lock`

**Solution:**
```bash
# Find the lock ID from the error message
export LOCK_ID="<lock-id-from-error>"

# Force unlock (use with caution)
terraform force-unlock $LOCK_ID
```

### Issue: Lambda Cold Start Timeout

**Error:** `Task timed out after 30.00 seconds`

**Solution:**
Edit `terraform/modules/lambda/variables.tf`:
```hcl
variable "timeout" {
  default = 60  # Increase from 30 to 60
}
```

### Issue: Cognito Authentication Fails

**Error:** `NotAuthorizedException: Incorrect username or password`

**Solution:**
```bash
# Reset user password
aws cognito-idp admin-set-user-password \
  --user-pool-id $USER_POOL_ID \
  --username testuser \
  --password "NewPassword123!" \
  --permanent

# Check user status
aws cognito-idp admin-get-user \
  --user-pool-id $USER_POOL_ID \
  --username testuser
```

### Issue: API Gateway 403 Forbidden

**Error:** `{"message":"Missing Authentication Token"}`

**Cause:** Incorrect endpoint URL or missing `/v1` stage

**Solution:**
```bash
# Ensure endpoint includes stage
echo $API_ENDPOINT  # Should include /v1 at the end
```

### Issue: ECR Image Push Fails

**Error:** `denied: Your authorization token has expired`

**Solution:**
```bash
# Re-authenticate to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REPO
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section above
2. Review CloudWatch Logs
3. Verify AWS service quotas and limits
4. Check AWS Personal Health Dashboard

## 🔐 Security Best Practices

- [ ] Use AWS Secrets Manager for client secrets
- [ ] Enable MFA for Cognito users in production
- [ ] Use VPC endpoints for AWS services
- [ ] Enable AWS WAF for API Gateway in production
- [ ] Regularly rotate Cognito client secrets
- [ ] Use least-privilege IAM policies
- [ ] Enable CloudTrail for audit logging
- [ ] Set up AWS Config rules for compliance

---

**Last Updated:** October 2025
