# =============================================================================
# GitHub OIDC Role - Variables
# =============================================================================

variable "name" {
  description = "Name prefix for resources"
  type        = string
  default     = "lightwave-deploy"
}

variable "environment" {
  description = "Environment (prod, staging, dev)"
  type        = string
  default     = "prod"
}

# -----------------------------------------------------------------------------
# GitHub Configuration
# -----------------------------------------------------------------------------

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "lightwave-media"
}

variable "github_repositories" {
  description = "List of GitHub repository names that can assume this role"
  type        = list(string)
  default     = ["lightwave-infrastructure-live"]
}

variable "restrict_to_main_branch" {
  description = "Whether to restrict to main branch only (more secure)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# OIDC Provider Configuration
# -----------------------------------------------------------------------------

variable "create_oidc_provider" {
  description = "Whether to create the GitHub OIDC provider (set false if already exists)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Permission Configuration
# -----------------------------------------------------------------------------

variable "lambda_function_arn" {
  description = "ARN of the Lambda function this role can invoke (deploy runner invoker)"
  type        = string
  default     = ""
}

variable "log_group_arns" {
  description = "List of CloudWatch Log Group ARNs this role can read"
  type        = list(string)
  default     = []
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster for monitoring deployments"
  type        = string
  default     = ""
}

variable "custom_policies" {
  description = "Map of custom IAM policies to attach (name => policy JSON)"
  type        = map(string)
  default     = {}
}

variable "managed_policy_arns" {
  description = "List of managed policy ARNs to attach"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
