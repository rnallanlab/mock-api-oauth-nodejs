#!/bin/bash
set -e

# Get values from Terraform outputs
cd terraform
USER_POOL_ID=$(terraform output -raw cognito_user_pool_id 2>/dev/null)
cd ..

if [ -z "$USER_POOL_ID" ]; then
    echo "❌ Could not get User Pool ID from Terraform outputs"
    echo "Make sure you have deployed the infrastructure first"
    exit 1
fi

# Default values
USERNAME="${1:-testuser}"
EMAIL="${2:-testuser@example.com}"
PASSWORD="${3:-MySecurePass123!}"

echo "================================"
echo "Creating Cognito User"
echo "================================"
echo "User Pool ID: $USER_POOL_ID"
echo "Username: $USERNAME"
echo "Email: $EMAIL"
echo ""

# Create user
echo "Creating user..."
aws cognito-idp admin-create-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$USERNAME" \
    --user-attributes Name=email,Value="$EMAIL" Name=email_verified,Value=true \
    --temporary-password "TempPass123!" \
    --message-action SUPPRESS

if [ $? -eq 0 ]; then
    echo "✓ User created"
else
    echo "⚠️  User might already exist, continuing..."
fi

# Set permanent password
echo "Setting permanent password..."
aws cognito-idp admin-set-user-password \
    --user-pool-id "$USER_POOL_ID" \
    --username "$USERNAME" \
    --password "$PASSWORD" \
    --permanent

if [ $? -eq 0 ]; then
    echo "✓ Password set"
else
    echo "❌ Failed to set password"
    exit 1
fi

# Verify user
echo "Verifying user..."
aws cognito-idp admin-get-user \
    --user-pool-id "$USER_POOL_ID" \
    --username "$USERNAME" \
    > /dev/null

if [ $? -eq 0 ]; then
    echo "✓ User verified"
else
    echo "❌ Failed to verify user"
    exit 1
fi

echo ""
echo "================================"
echo "✓ User created successfully!"
echo "================================"
echo ""
echo "Credentials:"
echo "  Username: $USERNAME"
echo "  Password: $PASSWORD"
echo ""
echo "Next Steps:"
echo "  - Test the API: ./scripts/test-api.sh"
echo ""
