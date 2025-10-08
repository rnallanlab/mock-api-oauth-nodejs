variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package (ZIP file)"
  type        = string
}

variable "handler" {
  description = "Lambda function handler"
  type        = string
  default     = "src/lambda.handler"
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs22.x"
}

variable "memory_size" {
  description = "Memory size for Lambda function in MB"
  type        = number
  default     = 512
}

variable "timeout" {
  description = "Timeout for Lambda function in seconds"
  type        = number
  default     = 30
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_app_client_id" {
  description = "Cognito App Client ID"
  type        = string
}

variable "log_level" {
  description = "Log level for the application"
  type        = string
  default     = "INFO"
}

variable "aws_region" {
  description = "AWS region for Cognito"
  type        = string
  default     = "us-east-1"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "api_gateway_arn" {
  description = "ARN of the API Gateway to allow invocation"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
