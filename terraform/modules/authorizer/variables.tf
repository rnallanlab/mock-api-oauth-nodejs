variable "function_name" {
  description = "Name of the Lambda authorizer function"
  type        = string
}

variable "auth_provider" {
  description = "Authentication provider type (cognito or azure)"
  type        = string

  validation {
    condition     = contains(["cognito", "azure"], var.auth_provider)
    error_message = "auth_provider must be either 'cognito' or 'azure'"
  }
}

variable "jwks_uri" {
  description = "JWKS endpoint URI for JWT validation"
  type        = string
}

variable "issuer" {
  description = "Expected JWT issuer"
  type        = string
}

variable "audience" {
  description = "Expected JWT audience"
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
