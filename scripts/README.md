# Client Management Scripts

This directory contains automation scripts for managing API clients.

## Available Scripts

### 1. `provision-client.sh` - Provision New Client

Creates a new client with Cognito App Client and API Key.

**Usage:**
```bash
./provision-client.sh <client-name> <environment>
```

**Example:**
```bash
./provision-client.sh acme-corp dev
```

**What it does:**
1. Validates client name format (lowercase, numbers, hyphens only)
2. Backs up `terraform.tfvars`
3. Adds client to `cognito_app_clients` list
4. Adds client to `api_keys` list
5. Prompts to run `terraform apply`
6. Retrieves and displays client credentials
7. Saves credentials to `client-credentials/` directory

**Output:**
- Backup file: `terraform/environments/{env}/terraform.tfvars.backup.{timestamp}`
- Credentials file: `client-credentials/{client-name}-{env}-{timestamp}.txt`

---

### 2. `revoke-client.sh` - Revoke Client Access

Removes a client and deletes their credentials.

**Usage:**
```bash
./revoke-client.sh <client-name> <environment>
```

**Example:**
```bash
./revoke-client.sh acme-corp dev
```

**What it does:**
1. Backs up `terraform.tfvars`
2. Removes client from `cognito_app_clients` list
3. Removes client from `api_keys` list
4. Shows confirmation prompt (requires typing "yes")
5. Prompts to run `terraform apply`
6. Destroys Cognito App Client and API Key

**⚠️ Warning:** This immediately revokes client access after terraform apply!

---

### 3. `list-clients.sh` - List All Clients

Displays all provisioned clients for an environment.

**Usage:**
```bash
./list-clients.sh <environment>
```

**Example:**
```bash
./list-clients.sh dev
```

**Output:**
```
=== Client List for dev Environment ===

Cognito App Clients:
  - demo-client
  - acme-corp
  - partner-xyz

API Keys:
  - demo-client
  - acme-corp
  - partner-xyz

Total Clients: 3
```

---

## Prerequisites

All scripts require:
- Bash shell
- Terraform installed
- `jq` installed (for JSON parsing)
- Proper AWS credentials configured
- Terraform state initialized in environment directory

## Security Notes

### Credential Files

**Location:** `client-credentials/` directory

**⚠️ IMPORTANT:**
- Credential files contain sensitive information
- Directory is in `.gitignore` (never commit!)
- Delete credential files after securely sharing with client
- Use encrypted channels to share credentials (AWS Secrets Manager, PGP, etc.)

### Best Practices

1. **Provision clients:**
   ```bash
   # Run from scripts/ directory
   ./provision-client.sh new-client dev

   # Securely share credentials from client-credentials/ directory
   # Then delete the file
   rm ../client-credentials/new-client-dev-*.txt
   ```

2. **List clients periodically:**
   ```bash
   ./list-clients.sh dev
   ./list-clients.sh prod
   ```

3. **Revoke inactive clients:**
   ```bash
   # Check if client is still active
   ./list-clients.sh dev

   # Revoke if no longer needed
   ./revoke-client.sh old-client dev
   ```

## Troubleshooting

### Error: "terraform.tfvars not found"

**Solution:** Ensure you're in the `scripts/` directory and the environment exists:
```bash
cd scripts/
ls -la ../terraform/environments/dev/terraform.tfvars
```

### Error: "Client already exists"

**Solution:** Client name is already in use. Choose a different name or revoke the existing client first:
```bash
./list-clients.sh dev
./revoke-client.sh existing-client dev
```

### Error: "Terraform plan failed"

**Solution:** Check Terraform state and AWS credentials:
```bash
cd ../terraform/environments/dev
terraform init
terraform plan
```

### Backup Files Accumulating

**Cleanup:** Remove old backup files periodically:
```bash
# List backups
ls -lh ../terraform/environments/dev/*.backup.*

# Remove backups older than 30 days
find ../terraform/environments/dev -name "*.backup.*" -mtime +30 -delete
```

## Directory Structure

```
scripts/
├── README.md                    # This file
├── provision-client.sh          # Provision new client
├── revoke-client.sh             # Revoke client access
└── list-clients.sh              # List all clients

client-credentials/              # Generated credentials (gitignored)
├── .gitignore
└── {client}-{env}-{timestamp}.txt

terraform/environments/
├── dev/
│   ├── terraform.tfvars         # Client configuration
│   └── *.tfvars.backup.*        # Automated backups
└── prod/
    └── terraform.tfvars
```

## Advanced Usage

### Scripted Provisioning (CI/CD)

```bash
#!/bin/bash
# Example: Automated client provisioning

CLIENT_NAME="automated-client"
ENVIRONMENT="dev"

# Provision
./provision-client.sh "$CLIENT_NAME" "$ENVIRONMENT" <<EOF
y
EOF

# Extract credentials programmatically
cd ../terraform/environments/$ENVIRONMENT
COGNITO_DOMAIN=$(terraform output -raw cognito_user_pool_domain)
CLIENT_ID=$(terraform output -raw cognito_client_id)
# ... etc

# Store in AWS Secrets Manager
aws secretsmanager create-secret \
  --name "api/${ENVIRONMENT}/${CLIENT_NAME}" \
  --secret-string "{\"client_id\":\"${CLIENT_ID}\",\"client_secret\":\"${CLIENT_SECRET}\"}"
```

### Bulk Client Operations

```bash
# Provision multiple clients
for client in client1 client2 client3; do
  ./provision-client.sh "$client" dev
done

# List clients across environments
for env in dev staging prod; do
  echo "=== $env ==="
  ./list-clients.sh "$env"
done
```

## Support

For issues or questions:
- Check `CLIENT-ONBOARDING.md` for client integration guide
- Review `ARCHITECTURE.md` for system design
- See Terraform documentation in `terraform/` directory
