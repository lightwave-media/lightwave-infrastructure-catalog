# =============================================================================
# Deploy Runner Invoker Lambda
# =============================================================================
#
# This module creates a Lambda function that triggers ECS Deploy Runner tasks.
# It validates requests and starts the appropriate Fargate task.
# =============================================================================

locals {
  name_prefix = "${var.name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "deploy-runner-invoker"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "invoker" {
  function_name = "${local.name_prefix}-invoker"
  description   = "Triggers ECS Deploy Runner tasks"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  handler     = "invoker.handler"
  runtime     = "python3.12"
  timeout     = 30
  memory_size = 256

  role = aws_iam_role.lambda.arn

  environment {
    variables = {
      CLUSTER_ARN               = var.ecs_cluster_arn
      SUBNET_IDS                = join(",", var.subnet_ids)
      SECURITY_GROUP_IDS        = join(",", var.security_group_ids)
      DOCKER_BUILDER_TASK_ARN   = var.docker_builder_task_arn
      TERRAFORM_RUNNER_TASK_ARN = var.terraform_runner_task_arn
      APP_DEPLOYER_TASK_ARN     = var.app_deployer_task_arn
      ALLOWED_APPS              = join(",", var.allowed_apps)
    }
  }

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Lambda IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-invoker-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Basic Lambda execution (CloudWatch Logs)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ECS task management
resource "aws_iam_role_policy" "lambda_ecs" {
  name = "ecs-task-management"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = var.ecs_cluster_arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = var.task_role_arns
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.invoker.function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# -----------------------------------------------------------------------------
# Lambda Function URL (for direct invocation from GitHub Actions)
# -----------------------------------------------------------------------------

resource "aws_lambda_function_url" "invoker" {
  count = var.create_function_url ? 1 : 0

  function_name      = aws_lambda_function.invoker.function_name
  authorization_type = "AWS_IAM" # Requires AWS auth (via OIDC)
}

# -----------------------------------------------------------------------------
# Lambda Permission for Cross-Account Invocation (if needed)
# -----------------------------------------------------------------------------

resource "aws_lambda_permission" "allow_cross_account" {
  count = length(var.allowed_invoker_arns) > 0 ? 1 : 0

  statement_id  = "AllowCrossAccountInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.invoker.function_name
  principal     = "*"

  # Restrict to specific ARNs
  source_arn = var.allowed_invoker_arns[0] # First ARN for now
}
