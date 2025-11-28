# =============================================================================
# ECS Deploy Runner - Main Configuration
# =============================================================================
#
# This module creates an ECS-based deployment runner that executes:
# - Docker image builds (using Kaniko)
# - Terraform/Terragrunt operations
# - App deployments (build + deploy combined)
#
# Based on Gruntwork Pipelines patterns.
# =============================================================================

locals {
  name_prefix = "${var.name}-${var.environment}"

  common_tags = merge(var.tags, {
    Module      = "ecs-deploy-runner"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------

resource "aws_ecs_cluster" "deploy_runner" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "deploy_runner" {
  cluster_name = aws_ecs_cluster.deploy_runner.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT" # Use spot for cost savings
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "docker_builder" {
  name              = "/ecs/${local.name_prefix}/docker-builder"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "terraform_runner" {
  name              = "/ecs/${local.name_prefix}/terraform-runner"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "app_deployer" {
  name              = "/ecs/${local.name_prefix}/app-deployer"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.common_tags
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "deploy_runner" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for ECS Deploy Runner tasks"
  vpc_id      = var.vpc_id

  # Outbound: Allow all (needed for ECR, GitHub, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-sg"
  })
}

# -----------------------------------------------------------------------------
# ECR Repository (for custom deployer image)
# -----------------------------------------------------------------------------

resource "aws_ecr_repository" "deployer" {
  count = var.create_ecr_repository ? 1 : 0

  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "deployer" {
  count = var.create_ecr_repository ? 1 : 0

  repository = aws_ecr_repository.deployer[0].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Task Definition: Docker Builder (Kaniko)
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "docker_builder" {
  family                   = "${local.name_prefix}-docker-builder"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.docker_builder_cpu
  memory                   = var.docker_builder_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.docker_builder_task.arn

  container_definitions = jsonencode([
    {
      name      = "kaniko"
      image     = var.kaniko_image
      essential = true

      # Kaniko requires these environment variables
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      # Command will be overridden at runtime
      command = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.docker_builder.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "kaniko"
        }
      }
    }
  ])

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Task Definition: Terraform Runner
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "terraform_runner" {
  family                   = "${local.name_prefix}-terraform-runner"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.terraform_runner_cpu
  memory                   = var.terraform_runner_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.terraform_runner_task.arn

  container_definitions = jsonencode([
    {
      name      = "terraform"
      image     = var.terraform_image
      essential = true

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "TF_IN_AUTOMATION"
          value = "true"
        }
      ]

      # Command will be overridden at runtime
      command    = ["plan"]
      entryPoint = ["/bin/sh", "-c"]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.terraform_runner.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "terraform"
        }
      }
    }
  ])

  tags = local.common_tags
}

# -----------------------------------------------------------------------------
# Task Definition: App Deployer (Build + Deploy Combined)
# -----------------------------------------------------------------------------

resource "aws_ecs_task_definition" "app_deployer" {
  family                   = "${local.name_prefix}-app-deployer"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.app_deployer_cpu
  memory                   = var.app_deployer_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.app_deployer_task.arn

  container_definitions = jsonencode([
    {
      name      = "deployer"
      image     = var.deployer_image != "" ? var.deployer_image : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository_name}:latest"
      essential = true

      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        }
      ]

      # These will be overridden at runtime
      command = []

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app_deployer.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "deployer"
        }
      }
    }
  ])

  tags = local.common_tags
}
