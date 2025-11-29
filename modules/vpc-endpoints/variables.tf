# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "Name prefix for VPC endpoints and security group"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where endpoints will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for security group ingress rules"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "List of private route table IDs for S3 gateway endpoint"
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for endpoint service names"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "enable_secretsmanager" {
  description = "Enable Secrets Manager VPC endpoint"
  type        = bool
  default     = true
}

variable "enable_ecr" {
  description = "Enable ECR VPC endpoints (API and DKR)"
  type        = bool
  default     = true
}

variable "enable_s3" {
  description = "Enable S3 VPC endpoint (gateway, free)"
  type        = bool
  default     = true
}

variable "enable_logs" {
  description = "Enable CloudWatch Logs VPC endpoint"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
