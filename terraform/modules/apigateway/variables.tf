variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "api_description" {
  description = "Description of the API Gateway"
  type        = string
  default     = "Orders API"
}

variable "stage_name" {
  description = "Name of the API Gateway stage"
  type        = string
  default     = "v1"
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  type        = string
}

variable "authorizer_invoke_arn" {
  description = "Invoke ARN of the Lambda authorizer function"
  type        = string
}

variable "authorizer_invocation_role_arn" {
  description = "ARN of the IAM role for API Gateway to invoke authorizer"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "api_clients" {
  description = "Map of API clients and their tiers"
  type = map(object({
    tier = string
  }))
}

variable "usage_tiers" {
  description = "Usage tier configurations"
  type = map(object({
    quota_limit  = number
    burst_limit  = number
    rate_limit   = number
  }))
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
