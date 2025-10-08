# SNS Topic for rotation notifications
resource "aws_sns_topic" "rotation_notifications" {
  name = "${var.environment}-client-rotation-notifications"
  tags = var.tags
}

# SNS Topic subscription (email)
resource "aws_sns_topic_subscription" "rotation_email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.rotation_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# IAM Role for Secret Rotation Lambda
resource "aws_iam_role" "rotation_lambda_role" {
  name = "${var.environment}-secret-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Secret Rotation Lambda
resource "aws_iam_role_policy" "rotation_lambda_policy" {
  name = "${var.environment}-secret-rotation-lambda-policy"
  role = aws_iam_role.rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient",
          "cognito-idp:UpdateUserPoolClient"
        ]
        Resource = var.cognito_user_pool_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.rotation_notifications.arn
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutRule",
          "events:PutTargets",
          "events:DeleteRule",
          "events:RemoveTargets"
        ]
        Resource = "arn:aws:events:*:*:rule/${var.environment}-rotate-*"
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:AddPermission",
          "lambda:RemovePermission"
        ]
        Resource = "arn:aws:lambda:*:*:function:${var.environment}-secret-rotation"
      }
    ]
  })
}

# CloudWatch Log Group for Rotation Lambda
resource "aws_cloudwatch_log_group" "rotation_lambda_logs" {
  name              = "/aws/lambda/${var.environment}-secret-rotation"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# Lambda Function for Secret Rotation
resource "aws_lambda_function" "secret_rotation" {
  filename         = "${path.module}/rotation_lambda.zip"
  function_name    = "${var.environment}-secret-rotation"
  role            = aws_iam_role.rotation_lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.rotation_lambda_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = 60

  environment {
    variables = {
      SNS_TOPIC_ARN          = aws_sns_topic.rotation_notifications.arn
      USER_POOL_ID           = var.cognito_user_pool_id
      ROTATION_DAYS          = var.rotation_days
      GRACE_PERIOD_DAYS      = var.grace_period_days
      ENVIRONMENT            = var.environment
      AWS_REGION             = data.aws_region.current.name
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.rotation_lambda_logs
  ]

  tags = var.tags
}

# Package Lambda function code
data "archive_file" "rotation_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/rotation_lambda.js"
  output_path = "${path.module}/rotation_lambda.zip"
}

# Get current AWS region
data "aws_region" "current" {}

# Lambda permission for EventBridge (allow any rotation rule to invoke)
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.secret_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${var.environment}-rotate-*"
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}
