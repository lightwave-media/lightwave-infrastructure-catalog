# ---------------------------------------------------------------------------------------------------------------------
# OUTPUTS
# ---------------------------------------------------------------------------------------------------------------------

output "budget_id" {
  description = "The ID of the budget"
  value       = aws_budgets_budget.this.id
}

output "budget_name" {
  description = "The name of the budget"
  value       = aws_budgets_budget.this.name
}

output "budget_arn" {
  description = "The ARN of the budget"
  value       = aws_budgets_budget.this.arn
}

output "sns_topic_arn" {
  description = "The ARN of the SNS topic for budget alerts (if created)"
  value       = var.create_sns_topic ? aws_sns_topic.budget_alerts[0].arn : null
}

output "sns_topic_name" {
  description = "The name of the SNS topic for budget alerts (if created)"
  value       = var.create_sns_topic ? aws_sns_topic.budget_alerts[0].name : null
}

output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch alarm for critical budget threshold (if created)"
  value       = var.create_cloudwatch_alarm ? aws_cloudwatch_metric_alarm.budget_critical[0].arn : null
}
