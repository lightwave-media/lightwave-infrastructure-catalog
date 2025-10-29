output "url" {
  description = "The URL of the Django service via the Application Load Balancer"
  value       = "http://${aws_lb.ecs.dns_name}:${var.alb_port}"
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.ecs.dns_name
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.ecs.arn
}

output "service_security_group_id" {
  description = "The ID of the security group attached to the ECS service"
  value       = local.service_sg_id
}

output "alb_security_group_id" {
  description = "The ID of the security group attached to the ALB"
  value       = local.alb_sg_id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.fargate.name
}

output "ecs_cluster_arn" {
  description = "The ARN of the ECS cluster"
  value       = aws_ecs_cluster.fargate.arn
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "ecs_service_arn" {
  description = "The ARN of the ECS service"
  value       = aws_ecs_service.service.id
}

output "task_definition_arn" {
  description = "The ARN of the ECS task definition"
  value       = aws_ecs_task_definition.service.arn
}

output "task_execution_role_arn" {
  description = "The ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "task_role_arn" {
  description = "The ARN of the ECS task role (for application-level AWS access)"
  value       = local.task_role_arn
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch log group for Django logs"
  value       = aws_cloudwatch_log_group.django.name
}
