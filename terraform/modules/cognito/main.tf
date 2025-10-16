# ========================================
# INTERNAL USER POOL (for client_credentials flow)
# ========================================
resource "aws_cognito_user_pool" "internal_pool" {
  name = "${var.organization}-internal-pool-${var.environment}"

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

  tags = merge(var.tags, {
    PoolType = "internal"
  })
}

# Cognito domain for internal pool
resource "aws_cognito_user_pool_domain" "internal_domain" {
  domain       = "${var.organization}-internal-${var.environment}"
  user_pool_id = aws_cognito_user_pool.internal_pool.id
}

# Resource server for internal pool custom scopes
resource "aws_cognito_resource_server" "internal_resource_server" {
  identifier   = "orders-api"
  name         = "Orders API Resource Server - Internal"
  user_pool_id = aws_cognito_user_pool.internal_pool.id

  scope {
    scope_name        = "read"
    scope_description = "Read access to orders"
  }

  scope {
    scope_name        = "write"
    scope_description = "Write access to orders"
  }
}

# App Client: teamA-service (client_credentials flow)
resource "aws_cognito_user_pool_client" "team_a_service" {
  name                                 = "teamA-service"
  user_pool_id                         = aws_cognito_user_pool.internal_pool.id
  generate_secret                      = true
  refresh_token_validity               = 30
  access_token_validity                = 60
  id_token_validity                    = 60
  token_validity_units {
    refresh_token = "days"
    access_token  = "minutes"
    id_token      = "minutes"
  }

  # Client credentials flow doesn't need user-based auth flows
  # Only keeping refresh token support
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Client credentials doesn't use user attributes, but keeping for compatibility
  read_attributes = [
    "email",
    "email_verified"
  ]

  write_attributes = [
    "email"
  ]

  prevent_user_existence_errors = "ENABLED"

  # OAuth 2.0 Client Credentials Flow (machine-to-machine)
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["orders-api/read", "orders-api/write"]

  supported_identity_providers = ["COGNITO"]

  depends_on = [aws_cognito_resource_server.internal_resource_server]
}

# NOTE: Test users are NOT needed for internal pool using client_credentials flow
# Client credentials flow uses Client ID + Secret only (no user accounts required)
# Uncomment below only if you need to test user-based auth flows on this pool
#
# resource "aws_cognito_user" "internal_test_user" {
#   count        = var.create_test_user ? 1 : 0
#   user_pool_id = aws_cognito_user_pool.internal_pool.id
#   username     = var.test_user_username
#
#   attributes = {
#     email          = var.test_user_email
#     email_verified = true
#   }
#
#   temporary_password = var.test_user_password
# }

# ========================================
# EXTERNAL USER POOL (for implicit flow) - COMMENTED OUT
# ========================================
# resource "aws_cognito_user_pool" "external_pool" {
#   name = "${var.organization}-external-pool-${var.environment}"
#
#   # Password policy
#   password_policy {
#     minimum_length                   = 8
#     require_lowercase                = true
#     require_uppercase                = true
#     require_numbers                  = true
#     require_symbols                  = true
#     temporary_password_validity_days = 7
#   }
#
#   # Account recovery
#   account_recovery_setting {
#     recovery_mechanism {
#       name     = "verified_email"
#       priority = 1
#     }
#   }
#
#   # Auto-verified attributes
#   auto_verified_attributes = ["email"]
#
#   # User attributes
#   schema {
#     attribute_data_type      = "String"
#     name                     = "email"
#     required                 = true
#     mutable                  = true
#     developer_only_attribute = false
#
#     string_attribute_constraints {
#       min_length = 1
#       max_length = 256
#     }
#   }
#
#   # MFA configuration
#   mfa_configuration = "OPTIONAL"
#
#   software_token_mfa_configuration {
#     enabled = true
#   }
#
#   # Username configuration
#   username_configuration {
#     case_sensitive = false
#   }
#
#   tags = merge(var.tags, {
#     PoolType = "external"
#   })
# }
#
# # Cognito domain for external pool
# resource "aws_cognito_user_pool_domain" "external_domain" {
#   domain       = "${var.organization}-external-${var.environment}"
#   user_pool_id = aws_cognito_user_pool.external_pool.id
# }
#
# # Resource server for external pool custom scopes
# resource "aws_cognito_resource_server" "external_resource_server" {
#   identifier   = "orders-api"
#   name         = "Orders API Resource Server - External"
#   user_pool_id = aws_cognito_user_pool.external_pool.id
#
#   scope {
#     scope_name        = "read"
#     scope_description = "Read access to orders"
#   }
#
#   scope {
#     scope_name        = "write"
#     scope_description = "Write access to orders"
#   }
# }
#
# # App Client: teamB-mobile (implicit flow)
# resource "aws_cognito_user_pool_client" "team_b_mobile" {
#   name                                 = "teamB-mobile"
#   user_pool_id                         = aws_cognito_user_pool.external_pool.id
#   generate_secret                      = false  # No secret for implicit flow
#   refresh_token_validity               = 30
#   access_token_validity                = 60
#   id_token_validity                    = 60
#   token_validity_units {
#     refresh_token = "days"
#     access_token  = "minutes"
#     id_token      = "minutes"
#   }
#
#   # Implicit flow requires user login - these auth flows are needed
#   explicit_auth_flows = [
#     "ALLOW_USER_PASSWORD_AUTH",    # Allow username/password login
#     "ALLOW_USER_SRP_AUTH",         # Secure Remote Password (recommended)
#     "ALLOW_REFRESH_TOKEN_AUTH"     # Allow token refresh
#   ]
#
#   read_attributes = [
#     "email",
#     "email_verified"
#   ]
#
#   write_attributes = [
#     "email"
#   ]
#
#   prevent_user_existence_errors = "ENABLED"
#
#   # OAuth 2.0 Implicit Flow (browser-based, user login)
#   allowed_oauth_flows_user_pool_client = true
#   allowed_oauth_flows                  = ["implicit"]
#   allowed_oauth_scopes                 = ["openid", "email", "profile"]
#
#   # Callback URLs for mobile app (update these with your actual URLs)
#   callback_urls = ["myapp://callback", "http://localhost:3000/callback"]
#   logout_urls   = ["myapp://logout", "http://localhost:3000/logout"]
#
#   supported_identity_providers = ["COGNITO"]
#
#   depends_on = [aws_cognito_resource_server.external_resource_server]
# }
#
# # Create test user for external pool (needed for implicit flow - user login)
# resource "aws_cognito_user" "external_test_user" {
#   count        = var.create_test_user ? 1 : 0
#   user_pool_id = aws_cognito_user_pool.external_pool.id
#   username     = var.test_user_username
#
#   attributes = {
#     email          = var.test_user_email
#     email_verified = true
#   }
#
#   temporary_password = var.test_user_password
# }
