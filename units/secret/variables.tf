# AWS Secrets Manager Secret Module - Variables

variable "secret_name" {
  description = "Name of the secret in AWS Secrets Manager. Should follow pattern: /{environment}/{service}/{secret_type}"
  type        = string

  validation {
    condition     = can(regex("^/[a-z0-9-]+/[a-z0-9-]+/[a-z_]+$", var.secret_name))
    error_message = "Secret name must follow pattern: /{environment}/{service}/{secret_type} (e.g., /prod/backend/database_password)"
  }
}

variable "description" {
  description = "Description of the secret"
  type        = string
  default     = ""
}

variable "secret_value" {
  description = "The secret value to store. Leave null if using auto_generate_password."
  type        = string
  default     = null
  sensitive   = true
}

variable "auto_generate_password" {
  description = "Automatically generate a random password for this secret"
  type        = bool
  default     = false
}

variable "password_length" {
  description = "Length of auto-generated password (only used if auto_generate_password = true)"
  type        = number
  default     = 32
}

variable "password_special_chars" {
  description = "Include special characters in auto-generated password"
  type        = bool
  default     = true
}

variable "rotation_trigger" {
  description = "Change this value to trigger password regeneration (only used if auto_generate_password = true)"
  type        = string
  default     = "1"
}

variable "enable_rotation" {
  description = "Enable automatic secret rotation"
  type        = bool
  default     = false
}

variable "rotation_days" {
  description = "Number of days between automatic rotations"
  type        = number
  default     = 30

  validation {
    condition     = var.rotation_days >= 1 && var.rotation_days <= 365
    error_message = "Rotation days must be between 1 and 365"
  }
}

variable "rotation_lambda_arn" {
  description = "ARN of Lambda function to use for rotation (required if enable_rotation = true)"
  type        = string
  default     = null
}

variable "recovery_window_in_days" {
  description = "Number of days to retain secret after deletion (0 for immediate deletion)"
  type        = number
  default     = 30

  validation {
    condition     = var.recovery_window_in_days >= 0 && var.recovery_window_in_days <= 30
    error_message = "Recovery window must be between 0 and 30 days"
  }
}

variable "kms_key_id" {
  description = "KMS key ID to encrypt the secret. If not specified, uses default AWS managed key."
  type        = string
  default     = null
}

variable "resource_policy" {
  description = "JSON resource-based policy for secret access control"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to the secret"
  type        = map(string)
  default     = {}
}
