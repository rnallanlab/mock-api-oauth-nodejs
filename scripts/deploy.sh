#!/bin/bash
set -e

# Default values
DEPLOYMENT_TYPE="${1:-lambda}"
AWS_REGION="${2:-us-east-1}"
ENVIRONMENT="${3:-dev}"

echo "================================"
echo "Deploying Mock Orders API (Node.js)"
echo "================================"
echo "Deployment Type: $DEPLOYMENT_TYPE"
echo "AWS Region: $AWS_REGION"
echo "Environment: $ENVIRONMENT"
echo ""

# Validate deployment type
if [ "$DEPLOYMENT_TYPE" != "lambda" ] && [ "$DEPLOYMENT_TYPE" != "ecs" ]; then
    echo "❌ Invalid deployment type. Must be 'lambda' or 'ecs'"
    echo "Usage: ./deploy.sh [lambda|ecs] [aws-region] [environment]"
    exit 1
fi

# Check AWS CLI
echo "Checking AWS CLI..."
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

# Verify AWS credentials
echo "Verifying AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Run 'aws configure'"
    exit 1
fi
echo "✓ AWS credentials verified"

# Check Terraform
echo "Checking Terraform..."
if ! command -v terraform &> /dev/null; then
    echo "❌ Terraform is not installed"
    exit 1
fi
echo "✓ Terraform version: $(terraform version | head -1)"

# Check if ZIP exists
if [ ! -f "server/dist/function.zip" ]; then
    echo "❌ ZIP file not found. Run './scripts/build.sh' first"
    exit 1
fi
echo "✓ Lambda package found"

# Navigate to Terraform directory
cd terraform

# Initialize Terraform
echo ""
echo "Initializing Terraform..."
terraform init

# Plan deployment
echo ""
echo "Planning deployment..."
terraform plan \
    -var="deployment_type=$DEPLOYMENT_TYPE" \
    -var="aws_region=$AWS_REGION" \
    -var="environment=$ENVIRONMENT" \
    -out=tfplan

# Ask for confirmation
echo ""
echo "================================"
echo "⚠️  WARNING: This will create AWS resources that may incur costs!"
echo "================================"
read -p "Do you want to proceed with deployment? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

# Apply deployment
echo ""
echo "Applying deployment..."
terraform apply tfplan
rm -f tfplan

# Save outputs
echo ""
echo "Saving outputs..."
terraform output > ../deployment-outputs.txt
terraform output -json > ../deployment-outputs.json

echo ""
echo "================================"
echo "✓ Deployment completed successfully!"
echo "================================"
echo ""
echo "Outputs saved to:"
echo "  - deployment-outputs.txt"
echo "  - deployment-outputs.json"
echo ""

# Display key outputs
API_ENDPOINT=$(terraform output -raw api_endpoint 2>/dev/null || echo "N/A")
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null || echo "N/A")
CLIENT_ID=$(terraform output -raw cognito_client_id 2>/dev/null || echo "N/A")

echo "Key Information:"
echo "  - API Endpoint: $API_ENDPOINT"
echo "  - User Pool ID: $USER_POOL_ID"
echo "  - Client ID: $CLIENT_ID"
echo ""
echo "Next Steps:"
echo "  1. Create a Cognito user: ./scripts/create-user.sh"
echo "  2. Test the API with test-api.sh"
echo ""
