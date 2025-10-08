# Credential Rotation Module

Automated credential rotation for Cognito App Client secrets using EventBridge and Lambda.

## Overview

This module implements **automatic credential rotation** with the following features:
- ✅ **90-day rotation cycle** (configurable)
- ✅ **14-day advance warning** (configurable grace period)
- ✅ **Email notifications** via SNS
- ✅ **No database required** - Uses EventBridge scheduled rules
- ✅ **Automatic rescheduling** after each rotation

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Provisioning                             │
│                                                                 │
│  provision-client.sh                                            │
│         │                                                       │
│         ├─> Lambda (action: schedule_rotation)                 │
│         │         │                                             │
│         │         ├─> Creates EventBridge Rule (Warning)        │
│         │         │   Triggers: 76 days from now (90-14)       │
│         │         │                                             │
│         │         └─> Creates EventBridge Rule (Rotation)       │
│         │             Triggers: 90 days from now                │
│         │                                                       │
│         └─> Sends welcome notification via SNS                  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Warning (Day 76)                             │
│                                                                 │
│  EventBridge Rule: {env}-rotate-warning-{client_id}             │
│         │                                                       │
│         └─> Lambda (action: send_warning)                       │
│                   │                                             │
│                   └─> Sends warning notification via SNS        │
│                       "Rotation in 14 days!"                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    Rotation (Day 90)                            │
│                                                                 │
│  EventBridge Rule: {env}-rotate-{client_id}                     │
│         │                                                       │
│         └─> Lambda (action: rotate)                             │
│                   │                                             │
│                   ├─> Cognito: Update client secret             │
│                   │                                             │
│                   ├─> SNS: Send new credentials                 │
│                   │                                             │
│                   ├─> Delete old EventBridge rules              │
│                   │                                             │
│                   └─> Create new rules for next rotation        │
│                       (90 days from now)                        │
└─────────────────────────────────────────────────────────────────┘
```

## No Database Design

Unlike traditional rotation systems that use DynamoDB to track rotation schedules, this implementation uses **EventBridge scheduled rules**:

- **Each client gets 2 EventBridge rules:**
  1. Warning rule: `{env}-rotate-warning-{client_id}`
  2. Rotation rule: `{env}-rotate-{client_id}`

- **Rules are self-managing:**
  - Created during client provisioning
  - Deleted and recreated after each rotation
  - No database queries needed

- **Benefits:**
  - ✅ No DynamoDB costs
  - ✅ Simpler architecture
  - ✅ AWS handles all scheduling
  - ✅ No polling required

## Usage

### 1. Deploy Module

```hcl
module "secret_rotation" {
  source = "./modules/secret-rotation"

  environment            = "dev"
  cognito_user_pool_id   = module.cognito.user_pool_id
  cognito_user_pool_arn  = module.cognito.user_pool_arn
  rotation_days          = 90
  grace_period_days      = 14
  notification_email     = "platform-team@example.com"

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
```

### 2. Provision Client with Rotation

When provisioning a new client, the rotation schedule is automatically initialized:

```bash
./scripts/provision-client.sh acme-corp dev
```

This will:
1. Create Cognito App Client
2. Create API Key
3. **Invoke Lambda to schedule rotation** (creates EventBridge rules)
4. Send welcome notification with rotation details

### 3. Manual Rotation (if needed)

```bash
./scripts/rotate-credentials.sh acme-corp dev
```

## Configuration

### Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `rotation_days` | 90 | Days between rotations |
| `grace_period_days` | 14 | Days before rotation to send warning |
| `notification_email` | "" | Email for notifications (must confirm SNS subscription) |
| `log_retention_days` | 30 | CloudWatch log retention |

### Outputs

| Output | Description |
|--------|-------------|
| `rotation_lambda_function_name` | Lambda function name |
| `rotation_lambda_arn` | Lambda ARN |
| `sns_topic_arn` | SNS topic ARN |

## Notifications

### 1. Welcome Notification (On Provisioning)

```
Subject: [DEV] New Client Provisioned: acme-corp

Client acme-corp has been provisioned in dev environment.

Client ID: 2abc123...
Next credential rotation scheduled for: 2026-01-04
Rotation frequency: Every 90 days
Grace period: 14 days before rotation

You will receive notifications:
- 14 days before rotation (warning)
- On the day of rotation (with new credentials)
```

### 2. Warning Notification (14 Days Before)

```
Subject: [DEV] ⚠️ Credential Rotation Warning: acme-corp

This is a 14-day advance notice.

Client: acme-corp
Client ID: 2abc123...
Environment: dev
Scheduled rotation date: 2026-01-04

ACTION REQUIRED:
The client secret for "acme-corp" will be rotated in 14 days.

What happens on rotation day:
1. Current secret will be invalidated
2. New secret will be generated
3. You will receive new credentials via email
4. Update your application with new credentials immediately

Prepare your deployment process to minimize downtime.
```

### 3. Rotation Notification (On Rotation Day)

```
Subject: [DEV] 🔄 Credentials Rotated: acme-corp

Client credentials have been rotated successfully.

Client: acme-corp
Client ID: 2abc123...
Environment: dev
Rotation Date: 2026-01-04
Next Rotation: 2026-04-04

NEW CREDENTIALS (update immediately):
─────────────────────────────────────
Client ID: 2abc123...
Client Secret: xyz789new-secret-here
─────────────────────────────────────

⚠️ IMPORTANT:
- The old secret is now INVALID
- Update your application immediately
- Test authentication after updating
- Store new secret securely

If you experience issues, contact the platform team immediately.
```

## EventBridge Rules

Each client has 2 scheduled rules:

### Warning Rule
- **Name:** `{env}-rotate-warning-{client_id}`
- **Schedule:** `cron(0 10 4 Dec ? 2025)` (76 days from provisioning)
- **Target:** Lambda with `action: send_warning`

### Rotation Rule
- **Name:** `{env}-rotate-{client_id}`
- **Schedule:** `cron(0 10 18 Dec ? 2025)` (90 days from provisioning)
- **Target:** Lambda with `action: rotate`

**After rotation:**
- Old rules are deleted
- New rules created for next cycle (90 days later)

## Lambda Actions

The rotation Lambda supports 3 actions:

### 1. `schedule_rotation`
```json
{
  "action": "schedule_rotation",
  "client_id": "2abc123..."
}
```
- Creates warning and rotation EventBridge rules
- Sends welcome notification

### 2. `send_warning`
```json
{
  "action": "send_warning",
  "client_id": "2abc123..."
}
```
- Triggered by warning rule (14 days before rotation)
- Sends advance notice email

### 3. `rotate`
```json
{
  "action": "rotate",
  "client_id": "2abc123..."
}
```
- Triggered by rotation rule (on rotation day)
- Updates Cognito client secret
- Sends new credentials via email
- Deletes old rules and creates new ones

## IAM Permissions

Lambda requires:

- **Cognito:**
  - `cognito-idp:DescribeUserPoolClient`
  - `cognito-idp:UpdateUserPoolClient`

- **EventBridge:**
  - `events:PutRule`
  - `events:PutTargets`
  - `events:DeleteRule`
  - `events:RemoveTargets`

- **SNS:**
  - `sns:Publish`

- **CloudWatch:**
  - `logs:CreateLogGroup`
  - `logs:CreateLogStream`
  - `logs:PutLogEvents`

## Monitoring

### CloudWatch Logs

All rotation events are logged to:
```
/aws/lambda/{environment}-secret-rotation
```

### Metrics to Monitor

- Lambda invocation count
- Lambda errors
- SNS publish failures
- EventBridge rule creation failures

### Sample Queries

**View all rotations:**
```
fields @timestamp, @message
| filter @message like /Successfully rotated/
| sort @timestamp desc
```

**View warnings sent:**
```
fields @timestamp, @message
| filter @message like /Sent warning notification/
| sort @timestamp desc
```

## Troubleshooting

### Warning Not Received

1. Check SNS subscription is confirmed
2. Verify EventBridge rule exists: `aws events list-rules --name-prefix {env}-rotate-warning`
3. Check Lambda logs for errors

### Rotation Failed

1. Check Lambda CloudWatch logs
2. Verify Cognito permissions
3. Manually rotate using: `./scripts/rotate-credentials.sh`

### Rules Not Created

1. Check Lambda has EventBridge permissions
2. Verify `schedule_rotation` was called during provisioning
3. Manually invoke Lambda:
   ```bash
   aws lambda invoke \
     --function-name dev-secret-rotation \
     --payload '{"action":"schedule_rotation","client_id":"CLIENT_ID"}' \
     response.json
   ```

## Cost Estimate (POC with 10 clients)

- **EventBridge Rules:** 20 rules × $0 (included in free tier)
- **Lambda Invocations:** ~30/month × $0 (free tier)
- **SNS:** 30 notifications × $0 (free tier)
- **CloudWatch Logs:** ~100MB × $0.50/GB = $0.05/month

**Total: ~$0.05/month** (essentially free for POC)

## Comparison: EventBridge vs DynamoDB

| Feature | EventBridge (Current) | DynamoDB |
|---------|----------------------|----------|
| **Cost** | ~$0.05/month | ~$2-5/month |
| **Complexity** | Low | Medium |
| **Query Ability** | Limited | Rich queries |
| **Scalability** | High | Very High |
| **Best For** | POC, <100 clients | Production, >100 clients |

## Security Considerations

1. **Credentials in Email:**
   - ⚠️ SNS email sends secrets in plain text
   - Consider using AWS Secrets Manager for production
   - Or use encrypted email (PGP)

2. **SNS Access:**
   - Ensure SNS topic has proper access controls
   - Subscribe only authorized email addresses

3. **Lambda Permissions:**
   - Follows principle of least privilege
   - Can only rotate clients in specified user pool

## Future Enhancements

- [ ] Support for AWS Secrets Manager instead of email
- [ ] Slack/Teams webhook integration
- [ ] Dry-run mode for testing
- [ ] Manual rotation override via API
- [ ] Rotation history tracking

---

**Last Updated:** 2025-10-06
