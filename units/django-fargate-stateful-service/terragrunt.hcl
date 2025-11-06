include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/django-fargate-service"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES - PostgreSQL and Redis
# ---------------------------------------------------------------------------------------------------------------------

dependency "postgresql" {
  config_path = "../postgresql"

  mock_outputs = {
    endpoint                = "postgres.example.com:5432"
    address                 = "postgres.example.com"
    port                    = 5432
    db_name                 = "django_db"
    username                = "postgres"
    connection_string       = "postgresql://postgres:password@postgres.example.com:5432/django_db"
    db_security_group_id    = "sg-12345"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

dependency "redis" {
  config_path = "../redis"

  mock_outputs = {
    primary_endpoint_address = "redis.example.com"
    port                     = 6379
    redis_url                = "redis://redis.example.com:6379/0"
    celery_broker_url        = "redis://redis.example.com:6379/1"
    redis_security_group_id  = "sg-67890"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Required inputs
  name               = values.name
  desired_count      = values.desired_count
  cpu                = values.cpu
  memory             = values.memory
  ecr_repository_url = values.ecr_repository_url
  image_tag          = values.image_tag

  # Django-specific configuration
  django_secret_key_arn   = values.django_secret_key_arn
  django_settings_module  = try(values.django_settings_module, "config.settings.prod")
  django_allowed_hosts    = values.django_allowed_hosts

  # Database configuration from PostgreSQL dependency
  database_url = dependency.postgresql.outputs.connection_string

  # Redis configuration from Redis dependency
  redis_url         = dependency.redis.outputs.redis_url
  celery_broker_url = dependency.redis.outputs.celery_broker_url

  # Optional inputs
  environment                       = try(values.environment, "prod")
  debug                             = try(values.debug, false)
  aws_region                        = try(values.aws_region, "us-east-1")
  vpc_id                            = try(values.vpc_id, null)
  private_subnet_ids                = try(values.private_subnet_ids, null)
  public_subnet_ids                 = try(values.public_subnet_ids, null)
  alb_port                          = try(values.alb_port, 80)
  container_port                    = try(values.container_port, 8000)
  health_check_path                 = try(values.health_check_path, "/health/live/")
  health_check_interval             = try(values.health_check_interval, 30)
  health_check_timeout              = try(values.health_check_timeout, 5)
  health_check_healthy_threshold    = try(values.health_check_healthy_threshold, 2)
  health_check_unhealthy_threshold  = try(values.health_check_unhealthy_threshold, 3)
  enable_ecs_managed_tags           = try(values.enable_ecs_managed_tags, true)
  enable_container_insights         = try(values.enable_container_insights, true)
  cloudwatch_log_retention_days     = try(values.cloudwatch_log_retention_days, 30)

  # Service security group IDs
  service_security_group_id = try(values.service_security_group_id, null)
  alb_security_group_id     = try(values.alb_security_group_id, null)

  # Task IAM role
  task_role_arn = try(values.task_role_arn, null)

  # Additional environment variables
  additional_environment_variables = merge(
    try(values.additional_environment_variables, {}),
    {
      # Add any custom environment variables here
      GUNICORN_WORKERS = try(values.gunicorn_workers, "4")
      GUNICORN_LOG_LEVEL = try(values.gunicorn_log_level, "info")
    }
  )

  # Tags
  tags = try(values.tags, {})
}

# ---------------------------------------------------------------------------------------------------------------------
# POST-APPLY CONFIGURATION
# ---------------------------------------------------------------------------------------------------------------------

# After deployment, need to configure security group rules to allow:
# 1. Django service → PostgreSQL (port 5432)
# 2. Django service → Redis (port 6379)
#
# These should be configured in a separate security group rules unit or stack
