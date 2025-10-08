terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "mock-api-oauth-aws"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Lambda Authorizer (for JWT validation - supports Cognito, Azure AD, etc.)
module "authorizer" {
  count  = var.deployment_type == "lambda" ? 1 : 0
  source = "./modules/authorizer"

  function_name       = "${var.project_name}-${var.environment}-authorizer"
  auth_provider       = var.auth_provider
  jwks_uri            = var.auth_provider == "cognito" ? "https://cognito-idp.${var.aws_region}.amazonaws.com/${module.cognito.user_pool_id}/.well-known/jwks.json" : var.auth_jwks_uri
  issuer              = var.auth_provider == "cognito" ? "https://cognito-idp.${var.aws_region}.amazonaws.com/${module.cognito.user_pool_id}" : var.auth_issuer
  audience            = var.auth_provider == "cognito" ? module.cognito.client_id : var.auth_audience
  log_retention_days  = 7

  tags = {
    Name = "${var.project_name}-authorizer"
  }
}

# Deploy with Lambda (comment this out if using ECS)
module "lambda_deployment" {
  count  = var.deployment_type == "lambda" ? 1 : 0
  source = "./modules/lambda"

  function_name         = "${var.project_name}-${var.environment}"
  lambda_zip_path       = var.lambda_zip_path
  cognito_user_pool_id  = module.cognito.user_pool_id
  cognito_app_client_id = module.cognito.client_id
  aws_region            = var.aws_region
  api_gateway_arn       = var.deployment_type == "lambda" ? module.api_gateway[0].execution_arn : ""

  tags = {
    Name = "${var.project_name}-lambda"
  }
}

module "api_gateway" {
  count  = var.deployment_type == "lambda" ? 1 : 0
  source = "./modules/apigateway"

  api_name                       = "${var.project_name}-${var.environment}"
  stage_name                     = var.api_stage_name
  lambda_invoke_arn              = module.lambda_deployment[0].function_invoke_arn
  authorizer_invoke_arn          = module.authorizer[0].function_invoke_arn
  authorizer_invocation_role_arn = module.authorizer[0].invocation_role_arn
  api_clients                    = var.api_clients
  usage_tiers                    = var.usage_tiers

  tags = {
    Name = "${var.project_name}-api-gateway"
  }
}

# Deploy with ECS Fargate (comment this out if using Lambda)
module "ecs_deployment" {
  count  = var.deployment_type == "ecs" ? 1 : 0
  source = "./modules/ecs"

  cluster_name          = "${var.project_name}-${var.environment}"
  ecr_repository_name   = "${var.project_name}-${var.environment}"
  cognito_user_pool_id  = module.cognito.user_pool_id
  cognito_app_client_id = module.cognito.client_id
  create_vpc            = var.create_vpc
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids

  tags = {
    Name = "${var.project_name}-ecs"
  }
}

# Cognito (shared by both Lambda and ECS)
module "cognito" {
  source = "./modules/cognito"

  user_pool_name   = "${var.project_name}-${var.environment}-pool"
  domain_prefix    = "${var.project_name}-${var.environment}-${random_string.cognito_domain_suffix.result}"
  create_test_user = var.create_test_user
  test_user_email  = var.test_user_email

  tags = {
    Name = "${var.project_name}-cognito"
  }
}

resource "random_string" "cognito_domain_suffix" {
  length  = 8
  special = false
  upper   = false
}
