output "function_name" {
  description = "Name of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.function_name
}

output "function_arn" {
  description = "ARN of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer function"
  value       = aws_lambda_function.authorizer.invoke_arn
}

output "invocation_role_arn" {
  description = "ARN of the IAM role for API Gateway to invoke authorizer"
  value       = aws_iam_role.invocation_role.arn
}

output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.authorizer_logs.name
}
