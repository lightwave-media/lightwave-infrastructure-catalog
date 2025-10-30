# AWS Secrets Manager Secret Module - Outputs

output "secret_id" {
  description = "ID of the secret (same as name)"
  value       = aws_secretsmanager_secret.this.id
}

output "secret_arn" {
  description = "ARN of the secret"
  value       = aws_secretsmanager_secret.this.arn
  sensitive   = true
}

output "secret_name" {
  description = "Name of the secret"
  value       = aws_secretsmanager_secret.this.name
}

output "secret_version_id" {
  description = "Version ID of the secret"
  value       = aws_secretsmanager_secret_version.this.version_id
}

output "rotation_enabled" {
  description = "Whether rotation is enabled for this secret"
  value       = var.enable_rotation
}

output "rotation_days" {
  description = "Number of days between rotations (if rotation enabled)"
  value       = var.rotation_days
}
