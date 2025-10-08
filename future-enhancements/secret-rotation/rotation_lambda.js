const {
  CognitoIdentityProviderClient,
  DescribeUserPoolClientCommand,
  UpdateUserPoolClientCommand
} = require('@aws-sdk/client-cognito-identity-provider');
const {
  EventBridgeClient,
  PutRuleCommand,
  PutTargetsCommand,
  DeleteRuleCommand,
  RemoveTargetsCommand
} = require('@aws-sdk/client-eventbridge');
const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const { LambdaClient, AddPermissionCommand } = require('@aws-sdk/client-lambda');

const cognitoClient = new CognitoIdentityProviderClient({});
const eventBridgeClient = new EventBridgeClient({});
const snsClient = new SNSClient({});
const lambdaClient = new LambdaClient({});

const ROTATION_DAYS = parseInt(process.env.ROTATION_DAYS || '90');
const GRACE_PERIOD_DAYS = parseInt(process.env.GRACE_PERIOD_DAYS || '14');
const USER_POOL_ID = process.env.USER_POOL_ID;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;
const ENVIRONMENT = process.env.ENVIRONMENT;
const AWS_REGION = process.env.AWS_REGION;

exports.handler = async (event) => {
  console.log('Rotation Lambda invoked:', JSON.stringify(event, null, 2));

  try {
    const action = event.action;
    const clientId = event.client_id;

    if (action === 'schedule_rotation') {
      // Called when provisioning a new client
      await scheduleRotation(clientId);
      await sendWelcomeNotification(clientId);
    } else if (action === 'send_warning') {
      // Called 14 days before rotation
      await sendWarningNotification(clientId);
    } else if (action === 'rotate') {
      // Called on rotation day
      await rotateClientSecret(clientId);
    } else {
      console.log('Unknown action:', action);
    }

    return {
      statusCode: 200,
      body: JSON.stringify({ message: 'Action completed successfully' })
    };
  } catch (error) {
    console.error('Error in rotation lambda:', error);
    throw error;
  }
};

// Schedule rotation for a new client (creates EventBridge rules)
async function scheduleRotation(clientId) {
  const now = new Date();
  const warningDate = new Date(now.getTime() + (ROTATION_DAYS - GRACE_PERIOD_DAYS) * 24 * 60 * 60 * 1000);
  const rotationDate = new Date(now.getTime() + ROTATION_DAYS * 24 * 60 * 60 * 1000);

  console.log(`Scheduling rotation for client: ${clientId}`);
  console.log(`Warning date: ${warningDate.toISOString()}`);
  console.log(`Rotation date: ${rotationDate.toISOString()}`);

  // Create warning rule (14 days before rotation)
  const warningRuleName = `${ENVIRONMENT}-rotate-warning-${clientId}`;
  const warningCron = getCronExpression(warningDate);

  await eventBridgeClient.send(new PutRuleCommand({
    Name: warningRuleName,
    Description: `Send rotation warning for ${clientId}`,
    ScheduleExpression: warningCron,
    State: 'ENABLED'
  }));

  await eventBridgeClient.send(new PutTargetsCommand({
    Rule: warningRuleName,
    Targets: [{
      Id: '1',
      Arn: `arn:aws:lambda:${AWS_REGION}:${await getAccountId()}:function:${ENVIRONMENT}-secret-rotation`,
      Input: JSON.stringify({
        action: 'send_warning',
        client_id: clientId
      })
    }]
  }));

  // Create rotation rule (on rotation day)
  const rotationRuleName = `${ENVIRONMENT}-rotate-${clientId}`;
  const rotationCron = getCronExpression(rotationDate);

  await eventBridgeClient.send(new PutRuleCommand({
    Name: rotationRuleName,
    Description: `Rotate credentials for ${clientId}`,
    ScheduleExpression: rotationCron,
    State: 'ENABLED'
  }));

  await eventBridgeClient.send(new PutTargetsCommand({
    Rule: rotationRuleName,
    Targets: [{
      Id: '1',
      Arn: `arn:aws:lambda:${AWS_REGION}:${await getAccountId()}:function:${ENVIRONMENT}-secret-rotation`,
      Input: JSON.stringify({
        action: 'rotate',
        client_id: clientId
      })
    }]
  }));

  console.log(`✓ Created EventBridge rules for ${clientId}`);
}

// Rotate secret for a specific client
async function rotateClientSecret(clientId) {
  console.log(`Starting rotation for client: ${clientId}`);

  try {
    // Get current client configuration
    const describeResponse = await cognitoClient.send(new DescribeUserPoolClientCommand({
      UserPoolId: USER_POOL_ID,
      ClientId: clientId
    }));

    const clientConfig = describeResponse.UserPoolClient;
    const clientName = clientConfig.ClientName;

    // Update client to generate new secret
    const updateResponse = await cognitoClient.send(new UpdateUserPoolClientCommand({
      UserPoolId: USER_POOL_ID,
      ClientId: clientId,
      ClientName: clientConfig.ClientName,
      AllowedOAuthFlows: clientConfig.AllowedOAuthFlows,
      AllowedOAuthScopes: clientConfig.AllowedOAuthScopes,
      AllowedOAuthFlowsUserPoolClient: clientConfig.AllowedOAuthFlowsUserPoolClient,
      GenerateSecret: true
    }));

    const newSecret = updateResponse.UserPoolClient.ClientSecret;

    // Send notification with new credentials
    await sendNotification(
      `🔄 Credentials Rotated: ${clientName}`,
      `Client credentials have been rotated successfully.\n\n` +
      `Client: ${clientName}\n` +
      `Client ID: ${clientId}\n` +
      `Environment: ${ENVIRONMENT}\n` +
      `Rotation Date: ${new Date().toISOString().split('T')[0]}\n` +
      `Next Rotation: ${new Date(Date.now() + ROTATION_DAYS * 24 * 60 * 60 * 1000).toISOString().split('T')[0]}\n\n` +
      `NEW CREDENTIALS (update immediately):\n` +
      `─────────────────────────────────────\n` +
      `Client ID: ${clientId}\n` +
      `Client Secret: ${newSecret}\n` +
      `─────────────────────────────────────\n\n` +
      `⚠️ IMPORTANT:\n` +
      `- The old secret is now INVALID\n` +
      `- Update your application immediately\n` +
      `- Test authentication after updating\n` +
      `- Store new secret securely\n\n` +
      `If you experience issues, contact the platform team immediately.`
    );

    // Delete old rotation rule and create new one for next rotation
    const oldRotationRuleName = `${ENVIRONMENT}-rotate-${clientId}`;
    const oldWarningRuleName = `${ENVIRONMENT}-rotate-warning-${clientId}`;

    // Remove old rules
    try {
      await eventBridgeClient.send(new RemoveTargetsCommand({
        Rule: oldRotationRuleName,
        Ids: ['1']
      }));
      await eventBridgeClient.send(new DeleteRuleCommand({
        Name: oldRotationRuleName
      }));

      await eventBridgeClient.send(new RemoveTargetsCommand({
        Rule: oldWarningRuleName,
        Ids: ['1']
      }));
      await eventBridgeClient.send(new DeleteRuleCommand({
        Name: oldWarningRuleName
      }));
    } catch (err) {
      console.warn('Could not delete old rules (may not exist):', err.message);
    }

    // Schedule next rotation
    await scheduleRotation(clientId);

    console.log(`✓ Successfully rotated secret for client: ${clientId}`);
    return newSecret;

  } catch (error) {
    console.error(`Error rotating secret for client ${clientId}:`, error);

    await sendNotification(
      `❌ Rotation Failed: ${clientId}`,
      `Failed to rotate credentials for client: ${clientId}\n\n` +
      `Environment: ${ENVIRONMENT}\n` +
      `Error: ${error.message}\n\n` +
      `Platform team has been notified. Manual intervention may be required.`
    );

    throw error;
  }
}

// Send warning notification
async function sendWarningNotification(clientId) {
  try {
    const describeResponse = await cognitoClient.send(new DescribeUserPoolClientCommand({
      UserPoolId: USER_POOL_ID,
      ClientId: clientId
    }));

    const clientName = describeResponse.UserPoolClient.ClientName;
    const rotationDate = new Date(Date.now() + GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000);

    await sendNotification(
      `⚠️ Credential Rotation Warning: ${clientName}`,
      `This is a ${GRACE_PERIOD_DAYS}-day advance notice.\n\n` +
      `Client: ${clientName}\n` +
      `Client ID: ${clientId}\n` +
      `Environment: ${ENVIRONMENT}\n` +
      `Scheduled rotation date: ${rotationDate.toISOString().split('T')[0]}\n\n` +
      `ACTION REQUIRED:\n` +
      `The client secret for "${clientName}" will be rotated in ${GRACE_PERIOD_DAYS} days.\n\n` +
      `What happens on rotation day:\n` +
      `1. Current secret will be invalidated\n` +
      `2. New secret will be generated\n` +
      `3. You will receive new credentials via email\n` +
      `4. Update your application with new credentials immediately\n\n` +
      `Prepare your deployment process to minimize downtime.`
    );

    console.log(`Sent warning notification for client: ${clientId}`);
  } catch (error) {
    console.error(`Error sending warning for ${clientId}:`, error);
  }
}

// Send welcome notification
async function sendWelcomeNotification(clientId) {
  try {
    const describeResponse = await cognitoClient.send(new DescribeUserPoolClientCommand({
      UserPoolId: USER_POOL_ID,
      ClientId: clientId
    }));

    const clientName = describeResponse.UserPoolClient.ClientName;
    const nextRotation = new Date(Date.now() + ROTATION_DAYS * 24 * 60 * 60 * 1000);

    await sendNotification(
      `New Client Provisioned: ${clientName}`,
      `Client ${clientName} has been provisioned in ${ENVIRONMENT} environment.\n\n` +
      `Client ID: ${clientId}\n` +
      `Next credential rotation scheduled for: ${nextRotation.toISOString().split('T')[0]}\n` +
      `Rotation frequency: Every ${ROTATION_DAYS} days\n` +
      `Grace period: ${GRACE_PERIOD_DAYS} days before rotation\n\n` +
      `You will receive notifications:\n` +
      `- ${GRACE_PERIOD_DAYS} days before rotation (warning)\n` +
      `- On the day of rotation (with new credentials)`
    );
  } catch (error) {
    console.error(`Error sending welcome notification for ${clientId}:`, error);
  }
}

// Send SNS notification
async function sendNotification(subject, message) {
  try {
    await snsClient.send(new PublishCommand({
      TopicArn: SNS_TOPIC_ARN,
      Subject: `[${ENVIRONMENT.toUpperCase()}] ${subject}`,
      Message: message
    }));
    console.log(`Notification sent: ${subject}`);
  } catch (error) {
    console.error('Error sending notification:', error);
  }
}

// Convert date to cron expression
function getCronExpression(date) {
  const minute = date.getUTCMinutes();
  const hour = date.getUTCHours();
  const day = date.getUTCDate();
  const month = date.getUTCMonth() + 1; // Months are 0-indexed
  const year = date.getUTCFullYear();

  // EventBridge cron: minute hour day month day-of-week year
  return `cron(${minute} ${hour} ${day} ${month} ? ${year})`;
}

// Get AWS Account ID
async function getAccountId() {
  const sts = new (require('@aws-sdk/client-sts').STSClient)({});
  const command = new (require('@aws-sdk/client-sts').GetCallerIdentityCommand)({});
  const response = await sts.send(command);
  return response.Account;
}
