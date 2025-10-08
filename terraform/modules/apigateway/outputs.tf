output "api_id" {
  description = "ID of the API Gateway"
  value       = aws_api_gateway_rest_api.orders_api.id
}

output "api_arn" {
  description = "ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.orders_api.arn
}

output "api_endpoint" {
  description = "Endpoint URL of the API Gateway"
  value       = aws_api_gateway_stage.orders_api.invoke_url
}

output "stage_name" {
  description = "Name of the API Gateway stage"
  value       = aws_api_gateway_stage.orders_api.stage_name
}

output "execution_arn" {
  description = "Execution ARN of the API Gateway"
  value       = aws_api_gateway_rest_api.orders_api.execution_arn
}

output "api_keys" {
  description = "Map of API client names to their API key IDs"
  value = {
    for client_name, key in aws_api_gateway_api_key.client_keys :
    client_name => key.id
  }
}

output "api_key_values" {
  description = "Map of API client names to their API key values (sensitive)"
  value = {
    for client_name, key in aws_api_gateway_api_key.client_keys :
    client_name => key.value
  }
  sensitive = true
}

output "usage_plans" {
  description = "Map of tier names to usage plan IDs"
  value = {
    for tier_name, plan in aws_api_gateway_usage_plan.tier_plans :
    tier_name => plan.id
  }
}
