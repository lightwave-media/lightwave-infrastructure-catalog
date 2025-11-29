# =============================================================================
# Deploy Runner Invoker - Variables
# =============================================================================

variable "name" {
  description = "Name prefix for resources"
  type        = string
  default     = "lightwave-deploy-runner"
}

variable "environment" {
  description = "Environment (prod, staging, dev)"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# ECS Configuration (from ecs-deploy-runner module)
# -----------------------------------------------------------------------------

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster to run tasks in"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for ECS tasks"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for ECS tasks"
  type        = list(string)
}

variable "docker_builder_task_arn" {
  description = "ARN of the Docker builder task definition"
  type        = string
}

variable "terraform_runner_task_arn" {
  description = "ARN of the Terraform runner task definition"
  type        = string
}

variable "app_deployer_task_arn" {
  description = "ARN of the app deployer task definition"
  type        = string
}

variable "task_role_arns" {
  description = "List of task role ARNs that Lambda can pass to ECS tasks"
  type        = list(string)
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "allowed_apps" {
  description = "List of allowed application names that can be deployed"
  type        = list(string)
  default     = ["cineos", "photographos", "createos", "lightwave-backend"]
}

variable "allowed_invoker_arns" {
  description = "List of ARNs allowed to invoke the Lambda function"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Function URL Configuration
# -----------------------------------------------------------------------------

variable "create_function_url" {
  description = "Whether to create a Lambda function URL"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
