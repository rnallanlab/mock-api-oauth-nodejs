output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = module.cognito.client_id
}

output "cognito_client_secret" {
  description = "Cognito App Client Secret"
  value       = module.cognito.client_secret
  sensitive   = true
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain"
  value       = module.cognito.user_pool_domain
}

# Lambda outputs
output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL (for Lambda deployment)"
  value       = var.deployment_type == "lambda" ? module.api_gateway[0].api_endpoint : null
}

output "lambda_function_name" {
  description = "Lambda function name (for Lambda deployment)"
  value       = var.deployment_type == "lambda" ? module.lambda_deployment[0].function_name : null
}

# ECS outputs
output "ecs_alb_endpoint" {
  description = "Application Load Balancer endpoint URL (for ECS deployment)"
  value       = var.deployment_type == "ecs" ? module.ecs_deployment[0].alb_endpoint : null
}

output "ecs_cluster_name" {
  description = "ECS Cluster name (for ECS deployment)"
  value       = var.deployment_type == "ecs" ? module.ecs_deployment[0].cluster_name : null
}

output "ecr_repository_url" {
  description = "ECR Repository URL (for ECS deployment)"
  value       = var.deployment_type == "ecs" ? module.ecs_deployment[0].ecr_repository_url : null
}

# General output
output "api_endpoint" {
  description = "API endpoint URL (either API Gateway or ALB depending on deployment type)"
  value       = var.deployment_type == "lambda" ? module.api_gateway[0].api_endpoint : module.ecs_deployment[0].alb_endpoint
}

output "deployment_type" {
  description = "Type of deployment (lambda or ecs)"
  value       = var.deployment_type
}

# API Key outputs (for Lambda deployment with API Gateway)
output "api_key_ids" {
  description = "Map of API client names to their API key IDs"
  value       = var.deployment_type == "lambda" ? module.api_gateway[0].api_keys : null
}

output "api_key_values" {
  description = "Map of API client names to their API key values (use with x-api-key header)"
  value       = var.deployment_type == "lambda" ? module.api_gateway[0].api_key_values : null
  sensitive   = true
}

output "usage_plan_ids" {
  description = "Map of tier names to usage plan IDs"
  value       = var.deployment_type == "lambda" ? module.api_gateway[0].usage_plans : null
}
