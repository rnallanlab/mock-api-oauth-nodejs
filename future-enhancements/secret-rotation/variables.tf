variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN"
  type        = string
}

variable "rotation_days" {
  description = "Number of days between rotations"
  type        = number
  default     = 90
}

variable "grace_period_days" {
  description = "Number of days grace period before rotation"
  type        = number
  default     = 14
}

variable "notification_email" {
  description = "Email address for rotation notifications"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
