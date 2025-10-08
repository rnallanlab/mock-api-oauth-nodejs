output "rotation_lambda_function_name" {
  description = "Name of the rotation Lambda function"
  value       = aws_lambda_function.secret_rotation.function_name
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda function"
  value       = aws_lambda_function.secret_rotation.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for rotation notifications"
  value       = aws_sns_topic.rotation_notifications.arn
}
