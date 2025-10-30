# Example 04: Backend Service Stack with Secret Management
#
# This Terragrunt Stack demonstrates a complete backend service deployment
# with proper secret management:
# 1. Create secrets (database password, JWT secret)
# 2. Create RDS database referencing secret
# 3. Create ECS service with secrets injected as environment variables
#
# This shows the recommended pattern for integrating secrets with services.

# Database password secret (auto-generated)
unit "database_password" {
  source = "../../../units/secret"

  inputs = {
    secret_name             = "/prod/backend/database_password"
    description             = "PostgreSQL master password for production backend"
    auto_generate_password  = true
    password_length         = 32
    password_special_chars  = true
    recovery_window_in_days = 30

    tags = {
      Environment = "prod"
      Service     = "backend"
      SecretType  = "database_password"
      ManagedBy   = "Terragrunt"
    }
  }
}

# JWT secret for application authentication
unit "jwt_secret" {
  source = "../../../units/secret"

  inputs = {
    secret_name             = "/prod/backend/jwt_secret_key"
    description             = "JWT signing key for production backend"
    auto_generate_password  = true
    password_length         = 64
    password_special_chars  = false # JWT secrets often don't need special chars
    recovery_window_in_days = 30

    tags = {
      Environment = "prod"
      Service     = "backend"
      SecretType  = "jwt_secret"
      ManagedBy   = "Terragrunt"
    }
  }
}

# PostgreSQL RDS instance using the secret
unit "database" {
  source = "../../../units/postgresql"

  # Wait for secret to be created
  dependencies = ["database_password"]

  inputs = {
    identifier     = "prod-backend-db"
    engine_version = "15.4"

    instance_class    = "db.t3.micro"
    allocated_storage = 20

    database_name   = "lightwave_prod"
    master_username = "admin"

    # Reference the secret ARN (not the value!)
    master_password_secret_arn = unit.database_password.outputs.secret_arn

    # RDS can manage password rotation automatically
    manage_master_user_password = true

    backup_retention_period = 7
    multi_az                = true

    vpc_id     = "vpc-xxxxx"
    subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]

    tags = {
      Environment = "prod"
      Service     = "backend"
      ManagedBy   = "Terragrunt"
    }
  }
}

# ECS Fargate service with secrets injected
unit "backend_service" {
  source = "../../../units/django-fargate-stateful-service"

  # Wait for database and secrets
  dependencies = ["database", "database_password", "jwt_secret"]

  inputs = {
    service_name = "backend"
    environment  = "prod"

    # Container configuration
    image_uri = "ghcr.io/lightwave-media/lightwave-backend:v1.0.0"
    cpu       = 512
    memory    = 1024

    # Environment variables (non-sensitive)
    environment_variables = {
      DJANGO_SETTINGS_MODULE = "core.settings.production"
      ALLOWED_HOSTS          = "api.lightwave-media.ltd"
      DEBUG                  = "False"
      DATABASE_HOST          = unit.database.outputs.endpoint
      DATABASE_PORT          = "5432"
      DATABASE_NAME          = "lightwave_prod"
      DATABASE_USER          = "admin"
    }

    # Secrets injected from AWS Secrets Manager
    # ECS will automatically fetch these at task startup
    secrets = [
      {
        name      = "DATABASE_PASSWORD"
        valueFrom = unit.database_password.outputs.secret_arn
      },
      {
        name      = "JWT_SECRET_KEY"
        valueFrom = unit.jwt_secret.outputs.secret_arn
      }
    ]

    # ECS task needs permission to read secrets
    task_policy_statements = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          unit.database_password.outputs.secret_arn,
          unit.jwt_secret.outputs.secret_arn
        ]
      }
    ]

    # Health check configuration
    health_check_path     = "/health"
    health_check_interval = 30

    # Auto-scaling configuration
    desired_count = 2
    min_capacity  = 1
    max_capacity  = 5

    tags = {
      Environment = "prod"
      Service     = "backend"
      ManagedBy   = "Terragrunt"
    }
  }
}

# Outputs for stack
output "database_endpoint" {
  description = "Database endpoint for connection"
  value       = unit.database.outputs.endpoint
}

output "service_url" {
  description = "Backend service URL"
  value       = "https://api.lightwave-media.ltd"
}

output "secret_arns" {
  description = "ARNs of created secrets"
  value = {
    database_password = unit.database_password.outputs.secret_arn
    jwt_secret        = unit.jwt_secret.outputs.secret_arn
  }
  sensitive = true
}

# Usage:
#
# 1. Deploy the entire stack:
#    terragrunt run-all apply
#
# 2. Rotate database password:
#    ../../../lightwave-infrastructure-live/scripts/rotate-secret.sh /prod/backend/database_password --generate --force-deployment
#
# 3. View secrets:
#    ../../../lightwave-infrastructure-live/scripts/list-secrets.sh --filter prod
#
# 4. Application code (Django) automatically gets secrets via environment:
#    DATABASE_PASSWORD = os.environ['DATABASE_PASSWORD']  # ECS injects this
#    JWT_SECRET_KEY = os.environ['JWT_SECRET_KEY']
#
# Security benefits:
# - Secrets never stored in Terraform state as plaintext
# - Auto-generated passwords are cryptographically secure
# - ECS injects secrets at runtime, not build time
# - IAM policies enforce least-privilege access
# - CloudTrail logs all secret access for auditing
