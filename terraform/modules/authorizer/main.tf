data "aws_region" "current" {}

# IAM Role for Lambda Authorizer
resource "aws_iam_role" "authorizer_role" {
  name = "${var.function_name}-role"

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
resource "aws_iam_role_policy_attachment" "authorizer_logs" {
  role       = aws_iam_role.authorizer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function for authorizer
resource "aws_lambda_function" "authorizer" {
  filename         = "${path.module}/authorizer.zip"
  function_name    = var.function_name
  role             = aws_iam_role.authorizer_role.arn
  handler          = "index.handler"
  runtime          = "nodejs22.x"
  timeout          = 30
  memory_size      = 256
  source_code_hash = fileexists("${path.module}/authorizer.zip") ? filebase64sha256("${path.module}/authorizer.zip") : null

  environment {
    variables = {
      PROVIDER_TYPE = var.auth_provider
      JWKS_URI      = var.jwks_uri
      ISSUER        = var.issuer
      AUDIENCE      = var.audience
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = var.tags
}

# CloudWatch Log Group for authorizer
resource "aws_cloudwatch_log_group" "authorizer_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# IAM Role for API Gateway to invoke authorizer
resource "aws_iam_role" "invocation_role" {
  name = "${var.function_name}-invocation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Policy to allow API Gateway to invoke Lambda
resource "aws_iam_role_policy" "invocation_policy" {
  name = "${var.function_name}-invocation-policy"
  role = aws_iam_role.invocation_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = aws_lambda_function.authorizer.arn
      }
    ]
  })
}
