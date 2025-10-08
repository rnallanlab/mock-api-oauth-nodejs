variable "user_pool_name" {
  description = "Name of the Cognito User Pool"
  type        = string
}

variable "domain_prefix" {
  description = "Domain prefix for the Cognito User Pool"
  type        = string
}

variable "client_name" {
  description = "Name of the Cognito User Pool Client"
  type        = string
  default     = "orders-api-client"
}

variable "create_test_user" {
  description = "Whether to create a test user"
  type        = bool
  default     = false
}

variable "test_user_username" {
  description = "Username for the test user"
  type        = string
  default     = "testuser"
}

variable "test_user_email" {
  description = "Email for the test user"
  type        = string
  default     = "testuser@example.com"
}

variable "test_user_password" {
  description = "Temporary password for the test user"
  type        = string
  sensitive   = true
  default     = "TempPass123!"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
