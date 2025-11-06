# AWS Budget Module

This Terraform module creates AWS Budgets with configurable alert thresholds and SNS notifications for cost monitoring.

## Features

- **Multi-threshold Alerts**: Configure multiple notification thresholds (e.g., 70%, 85%, 100%)
- **SNS Integration**: Automatic SNS topic creation for Slack/email notifications
- **Environment Filtering**: Filter costs by Environment tag for per-environment budgets
- **Cost Types Customization**: Control which cost types are included in the budget
- **CloudWatch Alarms**: Optional CloudWatch alarm for critical threshold breaches
- **Email & Slack Notifications**: Built-in support for email and Slack webhooks

## Usage

### Basic Usage

```hcl
module "prod_budget" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/budget"

  budget_name          = "prod-monthly-budget"
  monthly_budget_limit = 500
  environment          = "prod"

  alert_email_addresses = [
    "team@lightwave-media.ltd",
    "finance@lightwave-media.ltd"
  ]

  notification_thresholds = [
    {
      threshold_percentage = 70
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["management@lightwave-media.ltd"]
      sns_topic_arn        = null
    },
    {
      threshold_percentage = 85
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["team@lightwave-media.ltd"]
      sns_topic_arn        = module.prod_budget.sns_topic_arn
    },
    {
      threshold_percentage = 100
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["team@lightwave-media.ltd", "management@lightwave-media.ltd"]
      sns_topic_arn        = module.prod_budget.sns_topic_arn
    }
  ]

  tags = {
    Environment = "prod"
    ManagedBy   = "Terragrunt"
  }
}
```

### With Slack Integration

```hcl
module "prod_budget_with_slack" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/budget"

  budget_name          = "prod-monthly-budget"
  monthly_budget_limit = 500
  environment          = "prod"

  create_sns_topic      = true
  alert_email_addresses = ["team@lightwave-media.ltd"]
  slack_webhook_url     = var.slack_webhook_url # Store in Secrets Manager

  notification_thresholds = [
    {
      threshold_percentage = 80
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["team@lightwave-media.ltd"]
      sns_topic_arn        = null
    }
  ]
}
```

### Development Environment with Emergency Shutdown Trigger

```hcl
module "dev_budget" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/budget"

  budget_name          = "dev-monthly-budget"
  monthly_budget_limit = 50
  environment          = "dev"

  alert_email_addresses = ["team@lightwave-media.ltd"]

  notification_thresholds = [
    {
      threshold_percentage = 80
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["team@lightwave-media.ltd"]
      sns_topic_arn        = null
    },
    {
      threshold_percentage = 100
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["team@lightwave-media.ltd"]
      sns_topic_arn        = aws_sns_topic.dev_budget_critical.arn
    },
    {
      # Trigger emergency shutdown at 150%
      threshold_percentage = 150
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["team@lightwave-media.ltd"]
      sns_topic_arn        = aws_sns_topic.dev_emergency_shutdown.arn
    }
  ]

  create_cloudwatch_alarm = true

  tags = {
    Environment = "dev"
    ManagedBy   = "Terragrunt"
  }
}

# SNS topic that triggers emergency shutdown workflow
resource "aws_sns_topic" "dev_emergency_shutdown" {
  name = "dev-emergency-shutdown-trigger"
}

resource "aws_sns_topic_subscription" "emergency_shutdown_lambda" {
  topic_arn = aws_sns_topic.dev_emergency_shutdown.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.emergency_shutdown_trigger.arn
}
```

### Filter by Multiple Tags

```hcl
module "backend_budget" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/budget"

  budget_name          = "backend-services-budget"
  monthly_budget_limit = 300

  # Filter costs by multiple criteria
  cost_filters = {
    TagKeyValue = [
      "user:Environment$prod",
      "user:Service$backend"
    ]
  }

  alert_email_addresses = ["backend-team@lightwave-media.ltd"]

  notification_thresholds = [
    {
      threshold_percentage = 90
      threshold_type       = "PERCENTAGE"
      notification_type    = "ACTUAL"
      email_addresses      = ["backend-team@lightwave-media.ltd"]
      sns_topic_arn        = null
    }
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.8.0 |
| aws | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| budget_name | Name of the budget | `string` | n/a | yes |
| monthly_budget_limit | Monthly budget limit in USD | `number` | n/a | yes |
| environment | Environment to filter costs (e.g., 'prod', 'non-prod') | `string` | `null` | no |
| notification_thresholds | List of notification configurations | `list(object)` | See variables.tf | no |
| cost_filters | Additional cost filters | `map(list(string))` | `{}` | no |
| create_sns_topic | Whether to create SNS topic | `bool` | `true` | no |
| alert_email_addresses | Email addresses for alerts | `list(string)` | `[]` | no |
| slack_webhook_url | Slack webhook URL | `string` | `null` | no |
| create_cloudwatch_alarm | Create CloudWatch alarm | `bool` | `false` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| budget_id | The ID of the budget |
| budget_name | The name of the budget |
| budget_arn | The ARN of the budget |
| sns_topic_arn | The ARN of the SNS topic (if created) |
| sns_topic_name | The name of the SNS topic (if created) |
| cloudwatch_alarm_arn | The ARN of the CloudWatch alarm (if created) |

## Notes

### Email Subscriptions

AWS SNS requires email subscribers to confirm their subscription. After applying this module:
1. Check your email inbox for "AWS Notification - Subscription Confirmation"
2. Click the confirmation link
3. Budget alerts will start working after confirmation

### Slack Integration

To integrate with Slack:
1. Create a Slack app and enable Incoming Webhooks
2. Copy the webhook URL (e.g., `https://hooks.slack.com/services/...`)
3. Store it in AWS Secrets Manager
4. Reference it in your Terragrunt configuration

### Cost Filters

The `cost_filters` variable uses AWS Cost Explorer filter syntax:
- `TagKeyValue`: Filter by tag (format: `user:TagKey$TagValue`)
- `Service`: Filter by AWS service (e.g., `Amazon Elastic Compute Cloud - Compute`)
- `Region`: Filter by AWS region (e.g., `us-east-1`)

### Time Period

The budget automatically starts at the beginning of the current month and resets monthly.

## Examples

See the `examples/` directory in the infrastructure-catalog repository for complete examples:
- `examples/budget/prod/` - Production environment budget
- `examples/budget/non-prod/` - Non-production environment budget
- `examples/budget/service-specific/` - Budget for specific services

## Related Documentation

- [AWS Budgets Documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html)
- [Cost Allocation Tags](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html)
- [LightWave Media Cost Management SOP](../../lightwave-infrastructure-live/.agent/sops/SOP_COST_MANAGEMENT.md)

## License

See LICENSE.txt in the root of the repository.
