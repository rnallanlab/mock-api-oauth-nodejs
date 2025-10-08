# Credential Rotation Implementation

Automated 90-day credential rotation with 14-day grace period using EventBridge (no database required).

## Overview

Client credentials are automatically rotated every 90 days with advance warning notifications. The system uses EventBridge scheduled rules instead of a database for simplicity.

## How It Works

### Timeline

```
Day 0:   Client provisioned
         ├─> EventBridge rules created
         └─> Welcome notification sent

Day 76:  Warning notification sent
         └─> "Rotation in 14 days"

Day 90:  Credentials rotated
         ├─> Old secret invalidated
         ├─> New secret generated
         ├─> New credentials emailed
         └─> Next rotation scheduled (Day 180)
```

### Components

1. **EventBridge Rules** (per client)
   - `{env}-rotate-warning-{client_id}` - Triggers 76 days after provisioning
   - `{env}-rotate-{client_id}` - Triggers 90 days after provisioning

2. **Lambda Function**
   - Handles rotation logic
   - Manages EventBridge rules
   - Sends notifications

3. **SNS Topic**
   - Email notifications
   - Must confirm subscription

## Client Lifecycle

### 1. Provision Client

```bash
./scripts/provision-client.sh acme-corp dev
```

**What happens:**
- Cognito App Client created
- API Key created
- Lambda invoked to schedule rotation
- EventBridge rules created (Day 76 warning, Day 90 rotation)
- Welcome email sent

### 2. Warning (14 Days Before)

**EventBridge triggers Lambda on Day 76:**
- Warning email sent to team
- Includes rotation date and instructions

**Email received:**
```
Subject: ⚠️ Credential Rotation Warning: acme-corp

Rotation scheduled for: 2026-01-04 (in 14 days)

ACTION REQUIRED:
Prepare your deployment process for credential update.
```

### 3. Rotation (Day 90)

**EventBridge triggers Lambda on Day 90:**
- Cognito client secret updated
- Old secret invalidated immediately
- New credentials emailed
- Old EventBridge rules deleted
- New rules created for next rotation (Day 180)

**Email received:**
```
Subject: 🔄 Credentials Rotated: acme-corp

NEW CREDENTIALS (update immediately):
─────────────────────────────────────
Client ID: 2abc123...
Client Secret: xyz789new-secret-here
─────────────────────────────────────

⚠️ Old secret is now INVALID
Update your application immediately!
```

### 4. Client Updates Application

**Steps:**
1. Deploy new secret to production
2. Test authentication
3. Confirm success

**Expected downtime:** Minimal (if pre-planned)

## Manual Rotation

If you need to rotate before the scheduled date:

```bash
./scripts/rotate-credentials.sh acme-corp dev
```

This will:
1. Immediately rotate the secret
2. Send notification with new credentials
3. Reschedule next rotation (90 days from now)

## Configuration

### Rotation Frequency

Default: **90 days** (configurable in `terraform/modules/secret-rotation/variables.tf`)

```hcl
variable "rotation_days" {
  default = 90  # Change here
}
```

### Grace Period

Default: **14 days** (configurable)

```hcl
variable "grace_period_days" {
  default = 14  # Change here
}
```

### Email Notifications

Set notification email in Terraform:

```hcl
module "secret_rotation" {
  notification_email = "platform-team@example.com"
}
```

**Important:** You must confirm the SNS subscription via email!

## Notification Examples

### Welcome (On Provisioning)

```
[DEV] New Client Provisioned: acme-corp

Client acme-corp provisioned in dev environment.

Client ID: 2abc123...
Next rotation: 2026-01-04
Frequency: Every 90 days
Grace period: 14 days

You will receive:
- Warning 14 days before rotation
- New credentials on rotation day
```

### Warning (14 Days Before)

```
[DEV] ⚠️ Credential Rotation Warning: acme-corp

Rotation in 14 days!

Client: acme-corp
Scheduled date: 2026-01-04

Prepare your deployment process.
Current credentials will be invalidated.
```

### Rotation (Day 90)

```
[DEV] 🔄 Credentials Rotated: acme-corp

Rotation complete!

NEW CREDENTIALS:
Client ID: 2abc123...
Client Secret: xyz789...

⚠️ Old secret is INVALID
Update immediately!

Next rotation: 2026-04-04
```

## Architecture: No Database

Unlike traditional rotation systems, this uses **EventBridge rules** instead of DynamoDB:

### Traditional Approach (DynamoDB)
```
Lambda (daily cron)
  └─> Query DynamoDB for clients due for rotation
      └─> Rotate if needed
```

**Cost:** ~$2-5/month

### Our Approach (EventBridge)
```
Client provisioned
  └─> Create EventBridge rules with specific dates
      ├─> Warning rule (Day 76)
      └─> Rotation rule (Day 90)

Rules trigger Lambda at scheduled time
  └─> No database queries needed
```

**Cost:** ~$0.05/month (essentially free)

### Why EventBridge?

✅ **Simpler** - No database to manage
✅ **Cheaper** - No DynamoDB costs
✅ **Self-managing** - Rules recreate themselves after rotation
✅ **Perfect for POC** - Easy to understand and maintain

❌ **Limited visibility** - Can't easily query "all rotation schedules"
❌ **More rules** - 2 rules per client (not an issue for <100 clients)

## Monitoring

### View EventBridge Rules

```bash
# List all rotation rules
aws events list-rules --name-prefix dev-rotate

# View specific client's rules
aws events list-rules --name-prefix dev-rotate-acme-corp
```

### View Lambda Logs

```bash
# Tail logs
aws logs tail /aws/lambda/dev-secret-rotation --follow

# View recent rotations
aws logs filter-log-events \
  --log-group-name /aws/lambda/dev-secret-rotation \
  --filter-pattern "Successfully rotated"
```

### Check SNS Subscription

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform output -raw sns_topic_arn)
```

## Troubleshooting

### Problem: Warning Not Received

**Check:**
1. SNS subscription confirmed?
   ```bash
   aws sns list-subscriptions-by-topic --topic-arn <arn>
   ```
2. EventBridge rule exists?
   ```bash
   aws events list-rules --name-prefix dev-rotate-warning-acme-corp
   ```
3. Lambda has errors?
   ```bash
   aws logs tail /aws/lambda/dev-secret-rotation --since 1h
   ```

### Problem: Rotation Failed

**Check Lambda logs:**
```bash
aws logs tail /aws/lambda/dev-secret-rotation --filter-pattern ERROR
```

**Manual rotation fallback:**
```bash
./scripts/rotate-credentials.sh acme-corp dev
```

### Problem: Rules Not Created During Provisioning

**Manually trigger:**
```bash
aws lambda invoke \
  --function-name dev-secret-rotation \
  --payload '{"action":"schedule_rotation","client_id":"CLIENT_ID"}' \
  response.json
```

## Security Considerations

### ⚠️ Credentials in Email

**Current:** SNS sends secrets in plain text email

**Risks:**
- Email could be intercepted
- Email stored in mail servers

**For Production:**
- Use AWS Secrets Manager instead
- Or encrypt emails with PGP
- Or use Slack/Teams with encrypted channels

### SNS Topic Access

Ensure only authorized emails are subscribed:
```bash
# List subscriptions
aws sns list-subscriptions-by-topic --topic-arn <arn>

# Unsubscribe unauthorized
aws sns unsubscribe --subscription-arn <arn>
```

### Lambda Permissions

Lambda uses **least privilege**:
- Can only update Cognito clients in specified pool
- Can only create/delete EventBridge rules with `{env}-rotate-*` pattern
- Can only publish to specific SNS topic

## Cost Analysis (10 Clients)

### Components
- **EventBridge Rules:** 20 rules (10 clients × 2 rules)
- **Lambda Invocations:** ~30/month (10 welcome + 10 warning + 10 rotation)
- **SNS Notifications:** ~30/month
- **CloudWatch Logs:** ~100MB/month

### Monthly Cost
- EventBridge: $0 (free tier: 14M rules)
- Lambda: $0 (free tier: 1M requests)
- SNS: $0 (free tier: 1000 emails)
- CloudWatch: $0.05

**Total: ~$0.05/month** ✅

### Scaling to 100 Clients
- EventBridge: 200 rules = $0
- Lambda: 300 invocations/month = $0
- SNS: 300 emails/month = $0
- CloudWatch: ~1GB = $0.50

**Total: ~$0.50/month**

## Migration from DynamoDB (If Needed Later)

If you outgrow EventBridge and need DynamoDB:

1. Deploy DynamoDB table
2. Run migration script to populate table from EventBridge rules
3. Switch Lambda to query DynamoDB instead of creating rules
4. Delete old EventBridge rules

**Estimated effort:** 4-6 hours

## Best Practices

### For Platform Team

1. **Monitor SNS subscriptions** - Remove unauthorized subscribers
2. **Review Lambda logs** - Check for rotation failures
3. **Test rotation quarterly** - Verify end-to-end flow
4. **Keep email list updated** - Ensure right people get notifications

### For Client Teams

1. **Prepare deployment** - Have process ready when warning arrives
2. **Test credentials immediately** - After rotation, verify auth works
3. **Store securely** - Use environment variables or secret manager
4. **Monitor expiration** - Set reminders for rotation dates

## FAQ

**Q: Can I change rotation frequency?**
A: Yes, modify `rotation_days` in Terraform and redeploy

**Q: What happens if I miss the rotation window?**
A: Old secret is still invalidated. Use manual rotation script to get new credentials.

**Q: Can I disable rotation for a specific client?**
A: Yes, delete the EventBridge rules:
```bash
aws events delete-rule --name dev-rotate-acme-corp
aws events delete-rule --name dev-rotate-warning-acme-corp
```

**Q: How do I rotate immediately (before 90 days)?**
A: Use manual rotation script: `./scripts/rotate-credentials.sh acme-corp dev`

**Q: Can I see all rotation schedules?**
A: List EventBridge rules:
```bash
aws events list-rules --name-prefix dev-rotate | jq '.Rules[] | {Name, ScheduleExpression}'
```

---

**Last Updated:** 2025-10-06
**Status:** ✅ Implemented (No Database)
