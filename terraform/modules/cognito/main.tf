resource "aws_cognito_user_pool" "orders_api_pool" {
  name = var.user_pool_name

  # Password policy
  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Auto-verified attributes
  auto_verified_attributes = ["email"]

  # User attributes
  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # MFA configuration
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # Username configuration
  username_configuration {
    case_sensitive = false
  }

  tags = var.tags
}

resource "aws_cognito_user_pool_domain" "orders_api_domain" {
  domain       = var.domain_prefix
  user_pool_id = aws_cognito_user_pool.orders_api_pool.id
}

resource "aws_cognito_user_pool_client" "orders_api_client" {
  name                                 = var.client_name
  user_pool_id                         = aws_cognito_user_pool.orders_api_pool.id
  generate_secret                      = true
  refresh_token_validity               = 30
  access_token_validity                = 60
  id_token_validity                    = 60
  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_ADMIN_USER_PASSWORD_AUTH"
  ]

  read_attributes = [
    "email",
    "email_verified"
  ]

  write_attributes = [
    "email"
  ]

  prevent_user_existence_errors = "ENABLED"

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["orders-api/read"]

  supported_identity_providers = ["COGNITO"]
}

# Resource server for custom scopes
resource "aws_cognito_resource_server" "orders_api_resource_server" {
  identifier   = "orders-api"
  name         = "Orders API Resource Server"
  user_pool_id = aws_cognito_user_pool.orders_api_pool.id

  scope {
    scope_name        = "read"
    scope_description = "Read access to orders"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write access to orders"
  }
}

# Create a test user (optional, for testing purposes)
resource "aws_cognito_user" "test_user" {
  count        = var.create_test_user ? 1 : 0
  user_pool_id = aws_cognito_user_pool.orders_api_pool.id
  username     = var.test_user_username

  attributes = {
    email          = var.test_user_email
    email_verified = true
  }

  temporary_password = var.test_user_password
}
