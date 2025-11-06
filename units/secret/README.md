# AWS Secrets Manager Secret Module

This Terraform module creates and manages secrets in AWS Secrets Manager with support for automatic password generation, secret rotation, and custom KMS encryption.

## Features

- Create secrets with auto-generated or custom values
- Automatic secret rotation with Lambda integration
- KMS encryption support
- Resource-based access policies
- Configurable recovery window
- Follows LightWave naming conventions

## Usage

### Basic Secret (Manual Value)

```hcl
module "api_key" {
  source = "../../../lightwave-infrastructure-catalog/units/secret"

  secret_name  = "/prod/backend/stripe_api_key"
  description  = "Stripe API key for production backend"
  secret_value = "sk_live_xxxxxxxxxxxxx"

  tags = {
    Environment = "prod"
    Service     = "backend"
    SecretType  = "api_key"
  }
}
```

### Auto-Generated Password

```hcl
module "database_password" {
  source = "../../../lightwave-infrastructure-catalog/units/secret"

  secret_name           = "/prod/backend/database_password"
  description           = "PostgreSQL master password for production"
  auto_generate_password = true
  password_length       = 32
  password_special_chars = true

  tags = {
    Environment = "prod"
    Service     = "backend"
    SecretType  = "database_password"
  }
}
```

### Secret with Automatic Rotation

```hcl
module "rotating_password" {
  source = "../../../lightwave-infrastructure-catalog/units/secret"

  secret_name           = "/prod/backend/database_password"
  description           = "PostgreSQL master password with 30-day rotation"
  auto_generate_password = true
  enable_rotation       = true
  rotation_days         = 30
  rotation_lambda_arn   = "arn:aws:lambda:us-east-1:123456789012:function:RDSRotationLambda"

  tags = {
    Environment = "prod"
    Service     = "backend"
    SecretType  = "database_password"
  }
}
```

### Secret with KMS Encryption

```hcl
module "encrypted_secret" {
  source = "../../../lightwave-infrastructure-catalog/units/secret"

  secret_name  = "/prod/backend/jwt_secret"
  description  = "JWT signing key encrypted with custom KMS key"
  secret_value = "your-jwt-secret-here"
  kms_key_id   = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"

  tags = {
    Environment = "prod"
    Service     = "backend"
    SecretType  = "jwt_secret"
  }
}
```

### Secret with Resource Policy

```hcl
module "restricted_secret" {
  source = "../../../lightwave-infrastructure-catalog/units/secret"

  secret_name  = "/prod/backend/admin_credentials"
  description  = "Admin credentials with restricted access"
  secret_value = jsonencode({
    username = "admin"
    password = "secure-password"
  })

  resource_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowECSTaskAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::123456789012:role/ECSTaskRole"
        }
        Action   = "secretsmanager:GetSecretValue"
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment = "prod"
    Service     = "backend"
    SecretType  = "admin_credentials"
  }
}
```

## Naming Convention

Secrets must follow the LightWave naming pattern:

```
/{environment}/{service}/{secret_type}
```

Examples:
- `/prod/backend/database_password`
- `/prod/backend/jwt_secret_key`
- `/non-prod/redis/auth_token`
- `/prod/cloudflare/api_token`

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| secret_name | Name of the secret (must follow /{environment}/{service}/{secret_type} pattern) | string | - | yes |
| description | Description of the secret | string | "" | no |
| secret_value | The secret value to store (leave null if using auto_generate_password) | string | null | no |
| auto_generate_password | Automatically generate a random password | bool | false | no |
| password_length | Length of auto-generated password | number | 32 | no |
| password_special_chars | Include special characters in auto-generated password | bool | true | no |
| rotation_trigger | Change this value to trigger password regeneration | string | "1" | no |
| enable_rotation | Enable automatic secret rotation | bool | false | no |
| rotation_days | Number of days between automatic rotations | number | 30 | no |
| rotation_lambda_arn | ARN of Lambda function for rotation | string | null | no |
| recovery_window_in_days | Days to retain secret after deletion (0 for immediate) | number | 30 | no |
| kms_key_id | KMS key ID to encrypt the secret | string | null | no |
| resource_policy | JSON resource-based policy for access control | string | null | no |
| tags | Additional tags to apply to the secret | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| secret_id | ID of the secret (same as name) |
| secret_arn | ARN of the secret |
| secret_name | Name of the secret |
| secret_version_id | Version ID of the secret |
| rotation_enabled | Whether rotation is enabled |
| rotation_days | Number of days between rotations |

## Referencing Secrets in Other Modules

### In Terragrunt Configuration

```hcl
# In terragrunt.hcl
dependency "db_password" {
  config_path = "../secrets/database-password"
}

inputs = {
  database_password_arn = dependency.db_password.outputs.secret_arn
}
```

### In Terraform Module

```hcl
# variables.tf
variable "database_password_arn" {
  description = "ARN of database password in Secrets Manager"
  type        = string
  sensitive   = true
}

# main.tf
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.database_password_arn
}

resource "aws_db_instance" "this" {
  identifier      = "prod-postgres"
  engine          = "postgres"
  master_password = data.aws_secretsmanager_secret_version.db_password.secret_string
  # Other configuration...
}
```

## Best Practices

1. **Use Auto-Generation for Passwords**: Let Terraform generate secure random passwords
2. **Enable Rotation for Production**: Configure 30-day rotation for database passwords
3. **Tag Consistently**: Always include Environment, Service, and SecretType tags
4. **Use KMS for Sensitive Secrets**: Encrypt production secrets with custom KMS keys
5. **Set Recovery Window**: Use 30-day recovery for production, 0 for development
6. **Never Commit Secrets**: Use Terragrunt dependencies to reference secrets, never hardcode

## Secret Rotation

For automatic rotation:

1. Create a rotation Lambda function (AWS provides templates for RDS, Redshift, etc.)
2. Grant the Lambda function permission to update the secret and target resource
3. Configure the module with `enable_rotation = true` and provide `rotation_lambda_arn`
4. Test rotation in non-prod environment first

## Security Considerations

- Secrets are encrypted at rest using AWS KMS
- Use IAM policies to restrict `secretsmanager:GetSecretValue` access
- Enable CloudTrail logging for audit trail of secret access
- Rotate secrets regularly (30-90 days depending on type)
- Use resource policies for fine-grained access control
- Never output secret values in Terraform outputs (use sensitive = true)

## Related Documentation

- [SOP: Secrets Management](/.agent/sops/SOP_SECRETS_MANAGEMENT.md)
- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [LightWave Naming Conventions](/.agent/metadata/naming_conventions.yaml)
