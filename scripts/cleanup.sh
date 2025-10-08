#!/bin/bash
set -e

DEPLOYMENT_TYPE="${1:-lambda}"

echo "================================"
echo "⚠️  WARNING: CLEANUP SCRIPT"
echo "================================"
echo ""
echo "This will DESTROY all AWS resources created by Terraform!"
echo "Deployment Type: $DEPLOYMENT_TYPE"
echo ""
echo "Resources that will be deleted:"
echo "  - Cognito User Pool and all users"
echo "  - Lambda Function (if lambda deployment)"
echo "  - API Gateway (if lambda deployment)"
echo "  - ECS Cluster and Tasks (if ecs deployment)"
echo "  - ALB and Target Groups (if ecs deployment)"
echo "  - CloudWatch Log Groups"
echo "  - IAM Roles and Policies"
echo "  - All associated resources"
echo ""
read -p "Are you absolutely sure you want to proceed? Type 'destroy' to confirm: " CONFIRM

if [ "$CONFIRM" != "destroy" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

# Navigate to Terraform directory
cd terraform

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Destroy infrastructure
echo ""
echo "Destroying infrastructure..."
terraform destroy \
    -var="deployment_type=$DEPLOYMENT_TYPE" \
    -auto-approve

if [ $? -eq 0 ]; then
    echo ""
    echo "================================"
    echo "✓ Cleanup completed successfully!"
    echo "================================"
    echo ""
    echo "All AWS resources have been destroyed."
    echo ""

    # Clean up local files
    echo "Cleaning up local files..."
    rm -f ../deployment-outputs.txt
    rm -f ../deployment-outputs.json
    rm -f tfplan
    rm -rf .terraform.tfstate.lock.info

    echo "✓ Local files cleaned up"
else
    echo ""
    echo "❌ Cleanup failed"
    echo ""
    echo "Some resources may not have been destroyed."
    echo "Please check the AWS console and manually delete any remaining resources."
    exit 1
fi

echo ""
echo "Verifying cleanup..."

# Verify Lambda functions
LAMBDA_COUNT=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `orders-api`)].FunctionName' --output text | wc -w)
if [ "$LAMBDA_COUNT" -eq 0 ]; then
    echo "✓ No Lambda functions found"
else
    echo "⚠️  Found $LAMBDA_COUNT Lambda function(s) - may need manual cleanup"
fi

# Verify API Gateways
API_COUNT=$(aws apigateway get-rest-apis --query 'items[?contains(name, `orders-api`)].name' --output text | wc -w)
if [ "$API_COUNT" -eq 0 ]; then
    echo "✓ No API Gateways found"
else
    echo "⚠️  Found $API_COUNT API Gateway(s) - may need manual cleanup"
fi

# Verify Cognito User Pools
POOL_COUNT=$(aws cognito-idp list-user-pools --max-results 60 --query 'UserPools[?contains(Name, `orders-api`)].Name' --output text | wc -w)
if [ "$POOL_COUNT" -eq 0 ]; then
    echo "✓ No Cognito User Pools found"
else
    echo "⚠️  Found $POOL_COUNT Cognito User Pool(s) - may need manual cleanup"
fi

echo ""
echo "Cleanup verification complete."
echo ""
