# =============================================================================
# GitHub OIDC Role Module
# =============================================================================
#
# Creates an IAM role that GitHub Actions can assume via OIDC.
# No stored credentials required - uses GitHub's OIDC provider.
#
# Usage in GitHub Actions:
#   - uses: aws-actions/configure-aws-credentials@v4
#     with:
#       role-to-assume: <role_arn from this module>
#       aws-region: us-east-1
# =============================================================================

locals {
  name_prefix = "${var.name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "github-oidc-role"
    Environment = var.environment
    ManagedBy   = "terraform"
  })

  # Build the subject claim conditions
  # Format: repo:OWNER/REPO:ref:refs/heads/BRANCH or repo:OWNER/REPO:*
  subject_claims = [
    for repo in var.github_repositories :
    var.restrict_to_main_branch ?
    "repo:${var.github_org}/${repo}:ref:refs/heads/main" :
    "repo:${var.github_org}/${repo}:*"
  ]
}

data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------------
# GitHub OIDC Provider (create if not exists)
# -----------------------------------------------------------------------------

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (this is public and stable)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = local.common_tags
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# -----------------------------------------------------------------------------
# IAM Role for GitHub Actions
# -----------------------------------------------------------------------------

resource "aws_iam_role" "github_actions" {
  name        = "${local.name_prefix}-github-actions"
  description = "Role for GitHub Actions to deploy via ${var.name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.subject_claims
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Lambda Invoke Permission (for triggering deploy runner)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "lambda_invoke" {
  count = var.lambda_function_arn != "" ? 1 : 0

  name = "lambda-invoke"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = var.lambda_function_arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Logs Permission (for reading deployment logs)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "cloudwatch_logs" {
  count = length(var.log_group_arns) > 0 ? 1 : 0

  name = "cloudwatch-logs"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = var.log_group_arns
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# ECS Task Status Permission (for monitoring deployment)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "ecs_describe" {
  count = var.ecs_cluster_arn != "" ? 1 : 0

  name = "ecs-describe"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
        Condition = {
          ArnEquals = {
            "ecs:cluster" = var.ecs_cluster_arn
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Additional Custom Policies (if needed)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy" "custom" {
  for_each = var.custom_policies

  name   = each.key
  role   = aws_iam_role.github_actions.id
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}
