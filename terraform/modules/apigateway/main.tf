# API Gateway REST API
resource "aws_api_gateway_rest_api" "orders_api" {
  name        = var.api_name
  description = var.api_description

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# Lambda Authorizer (replaces Cognito authorizer)
resource "aws_api_gateway_authorizer" "lambda_authorizer" {
  name                             = "${var.api_name}-jwt-authorizer"
  rest_api_id                      = aws_api_gateway_rest_api.orders_api.id
  type                             = "REQUEST"
  authorizer_uri                   = var.authorizer_invoke_arn
  authorizer_credentials           = var.authorizer_invocation_role_arn
  identity_source                  = "method.request.header.Authorization"
  authorizer_result_ttl_in_seconds = 0 # Disable caching for testing
}

# /orders resource
resource "aws_api_gateway_resource" "orders" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  parent_id   = aws_api_gateway_rest_api.orders_api.root_resource_id
  path_part   = "orders"
}

# /orders/{orderId} resource
resource "aws_api_gateway_resource" "order_by_id" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  parent_id   = aws_api_gateway_resource.orders.id
  path_part   = "{orderId}"
}

# /health resource
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  parent_id   = aws_api_gateway_rest_api.orders_api.root_resource_id
  path_part   = "health"
}

# GET /orders method (requires JWT + API Key)
resource "aws_api_gateway_method" "get_orders" {
  rest_api_id      = aws_api_gateway_rest_api.orders_api.id
  resource_id      = aws_api_gateway_resource.orders.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true

  request_parameters = {
    "method.request.querystring.customerId" = true
    "method.request.querystring.startDate"  = false
    "method.request.querystring.endDate"    = false
    "method.request.querystring.limit"      = false
    "method.request.querystring.offset"     = false
    "method.request.header.x-api-key"       = true
  }
}

resource "aws_api_gateway_integration" "get_orders" {
  rest_api_id             = aws_api_gateway_rest_api.orders_api.id
  resource_id             = aws_api_gateway_resource.orders.id
  http_method             = aws_api_gateway_method.get_orders.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# GET /orders/{orderId} method (requires JWT + API Key)
resource "aws_api_gateway_method" "get_order_by_id" {
  rest_api_id      = aws_api_gateway_rest_api.orders_api.id
  resource_id      = aws_api_gateway_resource.order_by_id.id
  http_method      = "GET"
  authorization    = "CUSTOM"
  authorizer_id    = aws_api_gateway_authorizer.lambda_authorizer.id
  api_key_required = true

  request_parameters = {
    "method.request.path.orderId"     = true
    "method.request.header.x-api-key" = true
  }
}

resource "aws_api_gateway_integration" "get_order_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.orders_api.id
  resource_id             = aws_api_gateway_resource.order_by_id.id
  http_method             = aws_api_gateway_method.get_order_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# GET /health method (no auth, no API key)
resource "aws_api_gateway_method" "get_health" {
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_health" {
  rest_api_id             = aws_api_gateway_rest_api.orders_api.id
  resource_id             = aws_api_gateway_resource.health.id
  http_method             = aws_api_gateway_method.get_health.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}

# CORS for /orders
resource "aws_api_gateway_method" "options_orders" {
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  resource_id   = aws_api_gateway_resource.orders.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_orders_200" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "options_orders" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  resource_id = aws_api_gateway_resource.orders.id
  http_method = aws_api_gateway_method.options_orders.http_method
  status_code = aws_api_gateway_method_response.options_orders_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization,x-api-key'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# API Keys for different clients
resource "aws_api_gateway_api_key" "client_keys" {
  for_each = var.api_clients

  name    = "${var.api_name}-${each.key}-key"
  enabled = true

  tags = merge(var.tags, {
    Client = each.key
    Tier   = each.value.tier
  })
}

# Usage Plans with Rate Limiting
resource "aws_api_gateway_usage_plan" "tier_plans" {
  for_each = var.usage_tiers

  name        = "${var.api_name}-${each.key}-plan"
  description = "Usage plan for ${each.key} tier"

  api_stages {
    api_id = aws_api_gateway_rest_api.orders_api.id
    stage  = aws_api_gateway_stage.orders_api.stage_name
  }

  quota_settings {
    limit  = each.value.quota_limit
    period = "MONTH"
  }

  throttle_settings {
    burst_limit = each.value.burst_limit
    rate_limit  = each.value.rate_limit
  }

  tags = var.tags
}

# Associate API keys with usage plans
resource "aws_api_gateway_usage_plan_key" "client_associations" {
  for_each = var.api_clients

  key_id        = aws_api_gateway_api_key.client_keys[each.key].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.tier_plans[each.value.tier].id
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "orders_api" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.orders.id,
      aws_api_gateway_resource.order_by_id.id,
      aws_api_gateway_resource.health.id,
      aws_api_gateway_method.get_orders.id,
      aws_api_gateway_method.get_order_by_id.id,
      aws_api_gateway_method.get_health.id,
      aws_api_gateway_integration.get_orders.id,
      aws_api_gateway_integration.get_order_by_id.id,
      aws_api_gateway_integration.get_health.id,
      aws_api_gateway_authorizer.lambda_authorizer.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.get_orders,
    aws_api_gateway_integration.get_order_by_id,
    aws_api_gateway_integration.get_health,
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "orders_api" {
  deployment_id = aws_api_gateway_deployment.orders_api.id
  rest_api_id   = aws_api_gateway_rest_api.orders_api.id
  stage_name    = var.stage_name

  xray_tracing_enabled = true

  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
  #   format = jsonencode({
  #     requestId      = "$context.requestId"
  #     ip             = "$context.identity.sourceIp"
  #     caller         = "$context.identity.caller"
  #     user           = "$context.identity.user"
  #     requestTime    = "$context.requestTime"
  #     httpMethod     = "$context.httpMethod"
  #     resourcePath   = "$context.resourcePath"
  #     status         = "$context.status"
  #     protocol       = "$context.protocol"
  #     responseLength = "$context.responseLength"
  #     apiKey         = "$context.identity.apiKey"
  #   })
  # }

  tags = var.tags
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# API Gateway Method Settings
resource "aws_api_gateway_method_settings" "orders_api" {
  rest_api_id = aws_api_gateway_rest_api.orders_api.id
  stage_name  = aws_api_gateway_stage.orders_api.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled    = true
    # logging_level      = "INFO"  # Disabled - requires account-level CloudWatch role
    # data_trace_enabled = true    # Disabled - requires account-level CloudWatch role
  }
}
