data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_execution_role" {
  name               = "${var.function_name}-execution-role"
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

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Additional policy for CloudWatch metrics (Micrometer)
resource "aws_iam_role_policy" "lambda_cloudwatch_metrics" {
  name = "${var.function_name}-cloudwatch-metrics"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda function
resource "aws_lambda_function" "orders_api" {
  filename         = var.lambda_zip_path
  function_name    = var.function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = var.handler
  source_code_hash = filebase64sha256(var.lambda_zip_path)
  runtime          = var.runtime
  memory_size      = var.memory_size
  timeout          = var.timeout

  environment {
    variables = {
      COGNITO_USER_POOL_ID    = var.cognito_user_pool_id
      COGNITO_APP_CLIENT_ID   = var.cognito_app_client_id
      COGNITO_REGION          = var.aws_region
      LOG_LEVEL               = var.log_level
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orders_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_arn}/*/*"
}

# Lambda alias for versioning
resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Live alias for ${var.function_name}"
  function_name    = aws_lambda_function.orders_api.arn
  function_version = "$LATEST"
}
