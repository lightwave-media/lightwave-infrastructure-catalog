# AWS Secrets Manager Secret Module
# Creates and manages secrets in AWS Secrets Manager with optional automatic rotation

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Generate random password if auto_generate_password is true
resource "random_password" "this" {
  count = var.auto_generate_password ? 1 : 0

  length  = var.password_length
  special = var.password_special_chars

  # Ensure password changes trigger secret update
  keepers = {
    rotation_trigger = var.rotation_trigger
  }
}

# Create the secret in AWS Secrets Manager
resource "aws_secretsmanager_secret" "this" {
  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days
  kms_key_id              = var.kms_key_id

  tags = merge(
    var.tags,
    {
      Name      = var.secret_name
      ManagedBy = "Terraform"
    }
  )
}

# Store the secret value
resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id

  # Use auto-generated password if enabled, otherwise use provided value
  secret_string = var.auto_generate_password ? random_password.this[0].result : var.secret_value

  lifecycle {
    # Always ignore changes to secret_string after creation
    # This prevents Terraform from reverting manually updated or rotated secrets
    # If you need to update a secret value, use terraform taint or replace
    ignore_changes = [secret_string]
  }
}

# Configure automatic rotation if enabled and Lambda ARN provided
resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.enable_rotation && var.rotation_lambda_arn != null ? 1 : 0

  secret_id           = aws_secretsmanager_secret.this.id
  rotation_lambda_arn = var.rotation_lambda_arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }

  depends_on = [aws_secretsmanager_secret_version.this]
}

# Optional: Create resource-based policy for secret access control
resource "aws_secretsmanager_secret_policy" "this" {
  count = var.resource_policy != null ? 1 : 0

  secret_arn = aws_secretsmanager_secret.this.arn
  policy     = var.resource_policy
}
