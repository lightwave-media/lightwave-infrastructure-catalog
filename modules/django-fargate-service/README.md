# Django Fargate Service Module

This Terraform module deploys a Django REST Framework application on AWS ECS Fargate with production-ready configurations.

## Features

- **Django 5.0+** support with configurable settings module
- **JWT Authentication** via djangorestframework-simplejwt
- **Celery** task queue support with Redis broker
- **PostgreSQL** database integration via DATABASE_URL
- **Redis** caching and session backend
- **CloudWatch Logs** integration with configurable retention
- **Application Load Balancer** with health checks
- **Security Groups** with least-privilege access
- **Secrets Manager** integration for sensitive configuration
- **Circuit Breaker** deployment strategy for safe rollouts
- **Container Insights** enabled for monitoring

## Usage

```hcl
module "django_api" {
  source = "git::git@github.com:lightwave-media/lightwave-infrastructure-catalog.git//modules/django-fargate-service?ref=v1.0.0"

  name                  = "lightwave-api"
  desired_count         = 2
  cpu                   = 512
  memory                = 1024

  # Container image
  ecr_repository_url    = "123456789012.dkr.ecr.us-east-1.amazonaws.com/lightwave-api"
  image_tag             = "latest"

  # Django configuration
  django_settings_module = "config.settings.prod"
  django_allowed_hosts   = "api.lightwave-media.ltd,*.amazonaws.com"
  django_secret_key_arn  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:django-secret-key"

  # Database
  database_url          = "postgresql://user:pass@db.example.com:5432/django"

  # Redis (optional)
  redis_url             = "redis://redis.example.com:6379/0"

  # Environment
  environment           = "production"
  debug                 = false

  # Health checks
  health_check_path     = "/health/live/"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.1 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |

## Inputs

### Required Variables

| Name | Description | Type | Example |
|------|-------------|------|---------|
| name | Name of the Django ECS service | `string` | `"lightwave-api"` |
| desired_count | Number of container instances to run | `number` | `2` |
| cpu | CPU units (256, 512, 1024, etc.) | `number` | `512` |
| memory | Memory in MB (512, 1024, 2048, etc.) | `number` | `1024` |
| ecr_repository_url | URL of the ECR repository with Django image | `string` | `"123456789012.dkr.ecr.us-east-1.amazonaws.com/my-app"` |
| django_secret_key_arn | ARN of Secrets Manager secret for Django SECRET_KEY | `string` | `"arn:aws:secretsmanager:..."` |
| django_allowed_hosts | Comma-separated allowed hosts | `string` | `"api.example.com,*.amazonaws.com"` |
| database_url | PostgreSQL connection string | `string` (sensitive) | `"postgresql://user:pass@host:5432/db"` |

### Optional Variables

| Name | Description | Type | Default |
|------|-------------|------|---------|
| container_port | Port Django/Gunicorn listens on | `number` | `8000` |
| alb_port | Port the ALB listens on | `number` | `80` |
| image_tag | Docker image tag to deploy | `string` | `"latest"` |
| django_settings_module | Django settings module | `string` | `"config.settings.prod"` |
| redis_url | Redis connection URL | `string` | `null` |
| debug | Enable Django DEBUG mode | `bool` | `false` |
| environment | Environment name | `string` | `"production"` |
| aws_region | AWS region | `string` | `"us-east-1"` |
| celery_broker_url | Celery broker URL (defaults to redis_url) | `string` | `null` |
| service_sg_id | Security group ID for ECS service | `string` | `null` (creates new) |
| alb_sg_id | Security group ID for ALB | `string` | `null` (creates new) |
| cpu_architecture | CPU architecture (X86_64 or ARM64) | `string` | `"ARM64"` |
| health_check_path | Health check endpoint path | `string` | `"/health/live/"` |
| health_check_interval | Health check interval (seconds) | `number` | `30` |
| health_check_timeout | Health check timeout (seconds) | `number` | `5` |
| health_check_healthy_threshold | Consecutive successful checks required | `number` | `2` |
| health_check_unhealthy_threshold | Consecutive failed checks before unhealthy | `number` | `3` |
| log_retention_days | CloudWatch logs retention (days) | `number` | `30` |
| additional_environment_variables | Additional environment variables | `map(string)` | `{}` |
| task_role_arn | IAM role ARN for ECS task | `string` | `null` (creates new) |

## Outputs

| Name | Description |
|------|-------------|
| url | URL of the Django service via ALB |
| alb_dns_name | DNS name of the Application Load Balancer |
| alb_arn | ARN of the Application Load Balancer |
| service_security_group_id | Security group ID for ECS service |
| alb_security_group_id | Security group ID for ALB |
| ecs_cluster_name | Name of the ECS cluster |
| ecs_cluster_arn | ARN of the ECS cluster |
| ecs_service_name | Name of the ECS service |
| ecs_service_arn | ARN of the ECS service |
| task_definition_arn | ARN of the ECS task definition |
| task_execution_role_arn | ARN of the ECS task execution role |
| task_role_arn | ARN of the ECS task role |
| cloudwatch_log_group_name | Name of the CloudWatch log group |

## Environment Variables

The module automatically configures the following environment variables in the Django container:

### Automatically Set
- `DJANGO_SETTINGS_MODULE` - Django settings module
- `DJANGO_ALLOWED_HOSTS` - Allowed hosts from variable
- `DATABASE_URL` - PostgreSQL connection string
- `DEBUG` - Debug mode (boolean)
- `ENVIRONMENT` - Environment name
- `AWS_REGION` - AWS region
- `AWS_DEFAULT_REGION` - AWS region (for boto3)

### Conditional (if redis_url provided)
- `REDIS_URL` - Redis connection string
- `CELERY_BROKER_URL` - Celery broker URL (defaults to redis_url)

### From Secrets Manager
- `DJANGO_SECRET_KEY` - Django secret key (from django_secret_key_arn)

## Health Checks

The module configures two types of health checks:

### Container Health Check
- Runs inside the container via ECS
- Command: `curl -f http://localhost:8000/health/live/`
- Interval: 30 seconds
- Timeout: 5 seconds
- Start period: 60 seconds (grace period for Django startup)

### ALB Target Group Health Check
- Runs from the ALB to container instances
- Path: `/health/live/` (configurable via `health_check_path`)
- Interval: Configurable (default 30 seconds)
- Healthy threshold: 2 consecutive successes
- Unhealthy threshold: 3 consecutive failures

## IAM Roles

### Task Execution Role
- Used by ECS to pull images, write logs, access secrets
- Permissions:
  - AmazonECSTaskExecutionRolePolicy (managed)
  - Read secrets from Secrets Manager (custom policy)

### Task Role
- Used by Django application for AWS service access
- Permissions (default):
  - Write to CloudWatch Logs
- Can be customized by providing custom `task_role_arn`

## Security

### Security Groups
- **ECS Service SG**: Allows inbound on container_port from ALB only, outbound to all
- **ALB SG**: Allows inbound on alb_port from internet, outbound to all

### Secrets
- Django SECRET_KEY stored in AWS Secrets Manager
- Database credentials passed via secure DATABASE_URL variable (sensitive)
- Environment variables encrypted at rest in ECS task definition

## Deployment Strategy

- **Circuit Breaker**: Enabled with automatic rollback on failed deployments
- **Deregistration Delay**: 30 seconds for graceful shutdown
- **Deployment Order**: ALB → Target Group → ECS Service
- **Zero Downtime**: Rolling update with configurable desired_count

## Example: Complete Stack

```hcl
# Database
module "django_db" {
  source = "../modules/rds-postgres"
  name   = "lightwave-db"
  # ... db configuration
}

# Redis
module "django_redis" {
  source = "../modules/elasticache-redis"
  name   = "lightwave-redis"
  # ... redis configuration
}

# Django Service
module "django_api" {
  source = "../modules/django-fargate-service"

  name                  = "lightwave-api"
  desired_count         = 2
  cpu                   = 512
  memory                = 1024

  ecr_repository_url    = module.ecr.repository_url
  image_tag             = "latest"

  django_settings_module = "config.settings.prod"
  django_allowed_hosts   = "api.lightwave-media.ltd"
  django_secret_key_arn  = aws_secretsmanager_secret.django_secret.arn

  database_url          = "postgresql://${module.django_db.username}:${var.db_password}@${module.django_db.endpoint}/${module.django_db.database_name}"
  redis_url             = "redis://${module.django_redis.endpoint}:6379/0"

  environment           = "production"
  debug                 = false
}
```

## Monitoring

### CloudWatch Logs
- Log Group: `/ecs/${var.name}`
- Retention: Configurable (default 30 days)
- Stream Prefix: `ecs`

### Container Insights
- Automatically enabled on ECS cluster
- Provides CPU, memory, network, storage metrics
- Available in CloudWatch Container Insights dashboard

## Troubleshooting

### Container fails health checks
1. Verify Django is listening on port 8000
2. Check health endpoint returns HTTP 200: `curl http://localhost:8000/health/live/`
3. Review CloudWatch logs: `/ecs/${service_name}`
4. Verify DATABASE_URL is correct
5. Check DJANGO_ALLOWED_HOSTS includes ALB DNS name

### Database connection errors
1. Verify DATABASE_URL format
2. Check security group allows traffic from ECS service to RDS
3. Verify RDS endpoint is correct
4. Test connection from container: `psql $DATABASE_URL`

### Deployment failures
1. Check ECS service events in AWS Console
2. Review CloudWatch logs for task startup errors
3. Verify ECR image exists and is accessible
4. Check IAM role permissions for task execution

## Contributing

This module follows Gruntwork boilerplate standards. See `.boilerplate/` for template generation.

## License

MPL-2.0
