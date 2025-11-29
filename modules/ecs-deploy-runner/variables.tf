# =============================================================================
# ECS Deploy Runner - Variables
# =============================================================================

variable "name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "lightwave-deploy-runner"
}

variable "environment" {
  description = "Environment (prod, staging, dev)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where the deploy runner will run"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------------------
# Task Configuration
# -----------------------------------------------------------------------------

variable "docker_builder_cpu" {
  description = "CPU units for Docker builder task (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "docker_builder_memory" {
  description = "Memory for Docker builder task in MB"
  type        = number
  default     = 4096
}

variable "terraform_runner_cpu" {
  description = "CPU units for Terraform runner task"
  type        = number
  default     = 512
}

variable "terraform_runner_memory" {
  description = "Memory for Terraform runner task in MB"
  type        = number
  default     = 2048
}

variable "app_deployer_cpu" {
  description = "CPU units for app deployer task"
  type        = number
  default     = 1024
}

variable "app_deployer_memory" {
  description = "Memory for app deployer task in MB"
  type        = number
  default     = 4096
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Images
# -----------------------------------------------------------------------------

variable "kaniko_image" {
  description = "Kaniko Docker image for building containers"
  type        = string
  default     = "gcr.io/kaniko-project/executor:latest"
}

variable "terraform_image" {
  description = "Terraform/OpenTofu image for infrastructure deployments"
  type        = string
  default     = "hashicorp/terraform:1.9"
}

variable "deployer_image" {
  description = "Custom deployer image (will be built and pushed to ECR)"
  type        = string
  default     = "" # Will default to ECR repo URL if empty
}

# -----------------------------------------------------------------------------
# ECR Repository for Custom Images
# -----------------------------------------------------------------------------

variable "create_ecr_repository" {
  description = "Whether to create an ECR repository for custom deployer images"
  type        = bool
  default     = true
}

variable "ecr_repository_name" {
  description = "Name for the ECR repository"
  type        = string
  default     = "lightwave-deploy-runner"
}

# -----------------------------------------------------------------------------
# Secrets
# -----------------------------------------------------------------------------

variable "github_app_private_key_secret_arn" {
  description = "ARN of Secrets Manager secret containing GitHub App private key (for cloning private repos)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
