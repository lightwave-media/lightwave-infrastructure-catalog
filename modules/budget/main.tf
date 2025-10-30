# ---------------------------------------------------------------------------------------------------------------------
# AWS BUDGET MODULE
# Creates AWS Budget with multiple alert thresholds and SNS notifications
# ---------------------------------------------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BUDGET RESOURCE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_budgets_budget" "this" {
  name         = var.budget_name
  budget_type  = "COST"
  limit_amount = var.monthly_budget_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Time period starts at beginning of current month
  time_period_start = formatdate("YYYY-MM-01_00:00", timestamp())

  # Filter costs by environment tag if specified
  dynamic "cost_filter" {
    for_each = var.environment != null ? [1] : []
    content {
      name   = "TagKeyValue"
      values = ["user:Environment$${var.environment}"]
    }
  }

  # Additional cost filters
  dynamic "cost_filter" {
    for_each = var.cost_filters
    content {
      name   = cost_filter.key
      values = cost_filter.value
    }
  }

  # Alert notifications at different thresholds
  dynamic "notification" {
    for_each = var.notification_thresholds
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold_percentage
      threshold_type             = notification.value.threshold_type
      notification_type          = notification.value.notification_type
      subscriber_email_addresses = notification.value.email_addresses
      subscriber_sns_topic_arns  = notification.value.sns_topic_arn != null ? [notification.value.sns_topic_arn] : []
    }
  }

  # Optional cost types configuration
  cost_types {
    include_credit             = var.cost_types_include_credit
    include_discount           = var.cost_types_include_discount
    include_other_subscription = var.cost_types_include_other_subscription
    include_recurring          = var.cost_types_include_recurring
    include_refund             = var.cost_types_include_refund
    include_subscription       = var.cost_types_include_subscription
    include_support            = var.cost_types_include_support
    include_tax                = var.cost_types_include_tax
    include_upfront            = var.cost_types_include_upfront
    use_amortized              = var.cost_types_use_amortized
    use_blended                = var.cost_types_use_blended
  }

  lifecycle {
    # Budget name includes timestamp, prevent replacement on re-apply
    ignore_changes = [time_period_start]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SNS TOPIC FOR BUDGET ALERTS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sns_topic" "budget_alerts" {
  count = var.create_sns_topic ? 1 : 0

  name              = "${var.budget_name}-alerts"
  display_name      = "Budget Alerts for ${var.budget_name}"
  kms_master_key_id = var.sns_kms_key_id

  tags = merge(
    var.tags,
    {
      Name = "${var.budget_name}-alerts"
    }
  )
}

# SNS Topic Policy to allow AWS Budgets to publish
resource "aws_sns_topic_policy" "budget_alerts" {
  count = var.create_sns_topic ? 1 : 0

  arn = aws_sns_topic.budget_alerts[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsToPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.budget_alerts[0].arn
      }
    ]
  })
}

# Email subscriptions to SNS topic
resource "aws_sns_topic_subscription" "email" {
  for_each = var.create_sns_topic ? toset(var.alert_email_addresses) : []

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# Slack webhook subscription (HTTPS endpoint)
resource "aws_sns_topic_subscription" "slack" {
  count = var.create_sns_topic && var.slack_webhook_url != null ? 1 : 0

  topic_arn = aws_sns_topic.budget_alerts[0].arn
  protocol  = "https"
  endpoint  = var.slack_webhook_url
}

# ---------------------------------------------------------------------------------------------------------------------
# CLOUDWATCH ALARM FOR CRITICAL BUDGET ALERTS
# Optional: Create CloudWatch alarm when budget exceeds 100%
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "budget_critical" {
  count = var.create_cloudwatch_alarm ? 1 : 0

  alarm_name          = "${var.budget_name}-critical-threshold"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 21600 # 6 hours
  statistic           = "Maximum"
  threshold           = var.monthly_budget_limit
  alarm_description   = "Alert when ${var.budget_name} exceeds budget limit"
  treat_missing_data  = "notBreaching"

  dimensions = var.environment != null ? {
    Currency    = "USD"
    Environment = var.environment
    } : {
    Currency = "USD"
  }

  alarm_actions = var.create_sns_topic ? [aws_sns_topic.budget_alerts[0].arn] : []

  tags = merge(
    var.tags,
    {
      Name = "${var.budget_name}-critical-alarm"
    }
  )
}
