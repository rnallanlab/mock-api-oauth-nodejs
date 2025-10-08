variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "orders-api"
}

variable "deployment_type" {
  description = "Deployment type: 'lambda' or 'ecs'"
  type        = string
  default     = "lambda"

  validation {
    condition     = contains(["lambda", "ecs"], var.deployment_type)
    error_message = "deployment_type must be either 'lambda' or 'ecs'"
  }
}

# Lambda-specific variables
variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package (ZIP file)"
  type        = string
  default     = "../server/dist/function.zip"
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

# ECS-specific variables
variable "create_vpc" {
  description = "Whether to create a new VPC for ECS (only used when deployment_type is 'ecs')"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "VPC ID to use for ECS (only used when deployment_type is 'ecs' and create_vpc is false)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs to use for ECS (only used when deployment_type is 'ecs' and create_vpc is false)"
  type        = list(string)
  default     = []
}

# Authentication provider variables
variable "auth_provider" {
  description = "Authentication provider type: 'cognito' or 'azure'"
  type        = string
  default     = "cognito"

  validation {
    condition     = contains(["cognito", "azure"], var.auth_provider)
    error_message = "auth_provider must be either 'cognito' or 'azure'"
  }
}

variable "auth_jwks_uri" {
  description = "JWKS URI for JWT validation (auto-generated for Cognito)"
  type        = string
  default     = ""
}

variable "auth_issuer" {
  description = "JWT issuer (auto-generated for Cognito)"
  type        = string
  default     = ""
}

variable "auth_audience" {
  description = "JWT audience (auto-generated for Cognito)"
  type        = string
  default     = ""
}

# Cognito variables
variable "create_test_user" {
  description = "Whether to create a test user in Cognito"
  type        = bool
  default     = true
}

variable "test_user_email" {
  description = "Email for the test user"
  type        = string
  default     = "testuser@example.com"
}

# API Client and Usage Tier variables
variable "api_clients" {
  description = "Map of API clients and their tiers"
  type = map(object({
    tier = string
  }))
  default = {
    "demo-client" = { tier = "standard" }
  }
}

variable "usage_tiers" {
  description = "Usage tier configurations"
  type = map(object({
    quota_limit  = number
    burst_limit  = number
    rate_limit   = number
  }))
  default = {
    "standard" = {
      quota_limit  = 100      # 100 requests/month
      burst_limit  = 5        # 5 requests burst
      rate_limit   = 1        # 1 request/second sustained
    }
  }
}
