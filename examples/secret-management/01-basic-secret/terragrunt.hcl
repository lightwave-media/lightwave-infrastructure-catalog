# Example 01: Basic Secret Creation
#
# This example demonstrates creating a simple secret in AWS Secrets Manager
# with a manually provided value.
#
# Use case: API keys, service tokens, third-party credentials

include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../units/secret"
}

inputs = {
  # Secret name following LightWave convention: /{environment}/{service}/{secret_type}
  secret_name = "/non-prod/backend/stripe_api_key"

  # Description helps identify the secret's purpose
  description = "Stripe API key for non-production backend testing"

  # Manually provided secret value (in practice, use environment variable or CI/CD)
  # DO NOT commit actual secret values to Git
  secret_value = "sk_test_example_api_key_change_this"

  # Recovery window allows time to restore if accidentally deleted
  recovery_window_in_days = 7 # Use 0 for immediate deletion in dev

  # Tags for organization and cost tracking
  tags = {
    Environment = "non-prod"
    Service     = "backend"
    SecretType  = "api_key"
    ManagedBy   = "Terragrunt"
    CostCenter  = "engineering"
  }
}

# After applying this configuration:
# 1. Secret will be created in AWS Secrets Manager
# 2. Other Terragrunt modules can reference it via dependency
# 3. Applications can fetch it using AWS SDK
#
# Example application usage (Django):
#   from secrets_manager import get_secret
#   stripe_key = get_secret('/non-prod/backend/stripe_api_key')
#
# Example Terragrunt dependency:
#   dependency "stripe_key" {
#     config_path = "../secrets/stripe-api-key"
#   }
#   inputs = {
#     stripe_api_key_arn = dependency.stripe_key.outputs.secret_arn
#   }
