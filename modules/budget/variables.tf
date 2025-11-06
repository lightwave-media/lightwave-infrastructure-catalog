# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "budget_name" {
  description = "Name of the budget. Will be used to name all associated resources."
  type        = string
}

variable "monthly_budget_limit" {
  description = "Monthly budget limit in USD"
  type        = number

  validation {
    condition     = var.monthly_budget_limit > 0
    error_message = "Monthly budget limit must be greater than 0"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "environment" {
  description = "Environment to filter costs (e.g., 'prod', 'non-prod'). If null, budget applies to entire account."
  type        = string
  default     = null
}

variable "notification_thresholds" {
  description = "List of notification configurations with thresholds and recipients"
  type = list(object({
    threshold_percentage = number
    threshold_type       = string # PERCENTAGE or ABSOLUTE_VALUE
    notification_type    = string # ACTUAL or FORECASTED
    email_addresses      = list(string)
    sns_topic_arn        = optional(string)
  }))

  default = [
    {
      threshold_percentage = 80
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = []
      sns_topic_arn        = null
    },
    {
      threshold_percentage = 100
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = []
      sns_topic_arn        = null
    }
  ]

  validation {
    condition = alltrue([
      for notif in var.notification_thresholds :
      notif.threshold_percentage > 0 && notif.threshold_percentage <= 10000
    ])
    error_message = "Threshold percentage must be between 0 and 10000"
  }
}

variable "cost_filters" {
  description = "Additional cost filters to apply to the budget (e.g., by service, region)"
  type        = map(list(string))
  default     = {}
}

variable "create_sns_topic" {
  description = "Whether to create an SNS topic for budget alerts"
  type        = bool
  default     = true
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive budget alerts"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for budget alerts (optional)"
  type        = string
  default     = null
  sensitive   = true
}

variable "sns_kms_key_id" {
  description = "KMS key ID for SNS topic encryption (optional)"
  type        = string
  default     = null
}

variable "create_cloudwatch_alarm" {
  description = "Whether to create a CloudWatch alarm for critical budget threshold"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# COST TYPES CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

variable "cost_types_include_credit" {
  description = "Whether to include credits in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_discount" {
  description = "Whether to include discounts (e.g., Reserved Instance discounts) in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_other_subscription" {
  description = "Whether to include other subscription costs in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_recurring" {
  description = "Whether to include recurring costs in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_refund" {
  description = "Whether to include refunds in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_subscription" {
  description = "Whether to include subscription costs in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_support" {
  description = "Whether to include support costs in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_tax" {
  description = "Whether to include tax in the budget"
  type        = bool
  default     = true
}

variable "cost_types_include_upfront" {
  description = "Whether to include upfront costs in the budget"
  type        = bool
  default     = true
}

variable "cost_types_use_amortized" {
  description = "Whether to use amortized costs"
  type        = bool
  default     = false
}

variable "cost_types_use_blended" {
  description = "Whether to use blended costs"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# TAGGING
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
