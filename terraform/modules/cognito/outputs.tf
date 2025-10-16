# ========================================
# INTERNAL POOL OUTPUTS
# ========================================
output "user_pool_id" {
  description = "ID of the Internal Cognito User Pool"
  value       = aws_cognito_user_pool.internal_pool.id
}

output "internal_user_pool_id" {
  description = "ID of the Internal Cognito User Pool"
  value       = aws_cognito_user_pool.internal_pool.id
}

output "internal_user_pool_arn" {
  description = "ARN of the Internal Cognito User Pool"
  value       = aws_cognito_user_pool.internal_pool.arn
}

output "internal_user_pool_endpoint" {
  description = "Endpoint of the Internal Cognito User Pool"
  value       = aws_cognito_user_pool.internal_pool.endpoint
}

output "internal_user_pool_domain" {
  description = "Domain of the Internal Cognito User Pool"
  value       = aws_cognito_user_pool_domain.internal_domain.domain
}

output "user_pool_domain" {
  description = "Domain of the Internal Cognito User Pool (backward compatibility)"
  value       = aws_cognito_user_pool_domain.internal_domain.domain
}

output "team_a_service_client_id" {
  description = "ID of the teamA-service App Client"
  value       = aws_cognito_user_pool_client.team_a_service.id
}

output "team_a_service_client_secret" {
  description = "Secret of the teamA-service App Client"
  value       = aws_cognito_user_pool_client.team_a_service.client_secret
  sensitive   = true
}

output "client_id" {
  description = "ID of the teamA-service App Client (backward compatibility)"
  value       = aws_cognito_user_pool_client.team_a_service.id
}

output "client_secret" {
  description = "Secret of the teamA-service App Client (backward compatibility)"
  value       = aws_cognito_user_pool_client.team_a_service.client_secret
  sensitive   = true
}

output "internal_resource_server_identifier" {
  description = "Identifier of the Internal Cognito Resource Server"
  value       = aws_cognito_resource_server.internal_resource_server.identifier
}

output "resource_server_identifier" {
  description = "Identifier of the Internal Cognito Resource Server (backward compatibility)"
  value       = aws_cognito_resource_server.internal_resource_server.identifier
}

# ========================================
# EXTERNAL POOL OUTPUTS - COMMENTED OUT
# ========================================
# output "external_user_pool_id" {
#   description = "ID of the External Cognito User Pool"
#   value       = aws_cognito_user_pool.external_pool.id
# }
#
# output "external_user_pool_arn" {
#   description = "ARN of the External Cognito User Pool"
#   value       = aws_cognito_user_pool.external_pool.arn
# }
#
# output "external_user_pool_endpoint" {
#   description = "Endpoint of the External Cognito User Pool"
#   value       = aws_cognito_user_pool.external_pool.endpoint
# }
#
# output "external_user_pool_domain" {
#   description = "Domain of the External Cognito User Pool"
#   value       = aws_cognito_user_pool_domain.external_domain.domain
# }
#
# output "team_b_mobile_client_id" {
#   description = "ID of the teamB-mobile App Client"
#   value       = aws_cognito_user_pool_client.team_b_mobile.id
# }
#
# output "external_resource_server_identifier" {
#   description = "Identifier of the External Cognito Resource Server"
#   value       = aws_cognito_resource_server.external_resource_server.identifier
# }
