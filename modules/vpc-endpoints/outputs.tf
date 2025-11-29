# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "secretsmanager_endpoint_id" {
  description = "ID of the Secrets Manager VPC endpoint"
  value       = var.enable_secretsmanager ? aws_vpc_endpoint.secretsmanager[0].id : null
}

output "secretsmanager_endpoint_dns_names" {
  description = "DNS names of the Secrets Manager VPC endpoint"
  value       = var.enable_secretsmanager ? aws_vpc_endpoint.secretsmanager[0].dns_entry : null
}

output "ecr_api_endpoint_id" {
  description = "ID of the ECR API VPC endpoint"
  value       = var.enable_ecr ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "ecr_dkr_endpoint_id" {
  description = "ID of the ECR DKR VPC endpoint"
  value       = var.enable_ecr ? aws_vpc_endpoint.ecr_dkr[0].id : null
}

output "s3_endpoint_id" {
  description = "ID of the S3 VPC endpoint (gateway)"
  value       = var.enable_s3 ? aws_vpc_endpoint.s3[0].id : null
}

output "logs_endpoint_id" {
  description = "ID of the CloudWatch Logs VPC endpoint"
  value       = var.enable_logs ? aws_vpc_endpoint.logs[0].id : null
}
