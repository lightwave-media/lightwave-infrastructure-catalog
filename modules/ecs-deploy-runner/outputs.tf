# =============================================================================
# ECS Deploy Runner - Outputs
# =============================================================================

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.deploy_runner.arn
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.deploy_runner.name
}

output "security_group_id" {
  description = "ID of the security group for deploy runner tasks"
  value       = aws_security_group.deploy_runner.id
}

# -----------------------------------------------------------------------------
# Task Definitions
# -----------------------------------------------------------------------------

output "docker_builder_task_definition_arn" {
  description = "ARN of the Docker builder task definition"
  value       = aws_ecs_task_definition.docker_builder.arn
}

output "docker_builder_task_definition_family" {
  description = "Family of the Docker builder task definition"
  value       = aws_ecs_task_definition.docker_builder.family
}

output "terraform_runner_task_definition_arn" {
  description = "ARN of the Terraform runner task definition"
  value       = aws_ecs_task_definition.terraform_runner.arn
}

output "terraform_runner_task_definition_family" {
  description = "Family of the Terraform runner task definition"
  value       = aws_ecs_task_definition.terraform_runner.family
}

output "app_deployer_task_definition_arn" {
  description = "ARN of the app deployer task definition"
  value       = aws_ecs_task_definition.app_deployer.arn
}

output "app_deployer_task_definition_family" {
  description = "Family of the app deployer task definition"
  value       = aws_ecs_task_definition.app_deployer.family
}

# -----------------------------------------------------------------------------
# IAM Roles
# -----------------------------------------------------------------------------

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.task_execution.arn
}

output "docker_builder_task_role_arn" {
  description = "ARN of the Docker builder task role"
  value       = aws_iam_role.docker_builder_task.arn
}

output "terraform_runner_task_role_arn" {
  description = "ARN of the Terraform runner task role"
  value       = aws_iam_role.terraform_runner_task.arn
}

output "app_deployer_task_role_arn" {
  description = "ARN of the app deployer task role"
  value       = aws_iam_role.app_deployer_task.arn
}

# -----------------------------------------------------------------------------
# CloudWatch Logs
# -----------------------------------------------------------------------------

output "docker_builder_log_group" {
  description = "Name of the CloudWatch log group for Docker builder"
  value       = aws_cloudwatch_log_group.docker_builder.name
}

output "terraform_runner_log_group" {
  description = "Name of the CloudWatch log group for Terraform runner"
  value       = aws_cloudwatch_log_group.terraform_runner.name
}

output "app_deployer_log_group" {
  description = "Name of the CloudWatch log group for app deployer"
  value       = aws_cloudwatch_log_group.app_deployer.name
}

# -----------------------------------------------------------------------------
# ECR Repository
# -----------------------------------------------------------------------------

output "ecr_repository_url" {
  description = "URL of the ECR repository for custom deployer images"
  value       = var.create_ecr_repository ? aws_ecr_repository.deployer[0].repository_url : ""
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository for custom deployer images"
  value       = var.create_ecr_repository ? aws_ecr_repository.deployer[0].arn : ""
}

# -----------------------------------------------------------------------------
# Configuration for Lambda Invoker
# -----------------------------------------------------------------------------

output "invoker_config" {
  description = "Configuration map to pass to the deploy-runner-invoker module"
  value = {
    cluster_arn     = aws_ecs_cluster.deploy_runner.arn
    subnet_ids      = var.private_subnet_ids
    security_groups = [aws_security_group.deploy_runner.id]

    task_definitions = {
      docker_builder = {
        arn    = aws_ecs_task_definition.docker_builder.arn
        family = aws_ecs_task_definition.docker_builder.family
      }
      terraform_runner = {
        arn    = aws_ecs_task_definition.terraform_runner.arn
        family = aws_ecs_task_definition.terraform_runner.family
      }
      app_deployer = {
        arn    = aws_ecs_task_definition.app_deployer.arn
        family = aws_ecs_task_definition.app_deployer.family
      }
    }

    log_groups = {
      docker_builder   = aws_cloudwatch_log_group.docker_builder.name
      terraform_runner = aws_cloudwatch_log_group.terraform_runner.name
      app_deployer     = aws_cloudwatch_log_group.app_deployer.name
    }
  }
}
