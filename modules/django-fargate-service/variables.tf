# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the Django ECS service"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the service"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for Application Load Balancer"
  type        = list(string)
}

variable "desired_count" {
  description = "How many instances of the Django service to run"
  type        = number
}

variable "cpu" {
  description = "Number of CPU units to allocate for the service. Note: only certain cpu and memory combinations are allowed. See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html"
  type        = number
}

variable "memory" {
  description = "The amount of memory, in MB, to allocate for the service. Note: only certain cpu and memory combinations are allowed. See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html"
  type        = number
}

variable "container_port" {
  description = "The port Django/Gunicorn listens on inside the container"
  type        = number
  default     = 8000
}

variable "alb_port" {
  description = "The port the ALB listens on for HTTP requests"
  type        = number
  default     = 80
}

variable "ecr_repository_url" {
  description = "The URL of the ECR repository containing the Django Docker image"
  type        = string
}

variable "image_tag" {
  description = "The tag of the Docker image to deploy (e.g., 'latest' or git SHA)"
  type        = string
  default     = "latest"
}

# ---------------------------------------------------------------------------------------------------------------------
# DJANGO-SPECIFIC VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "django_settings_module" {
  description = "Django settings module to use (e.g., 'config.settings.prod')"
  type        = string
  default     = "config.settings.prod"
}

variable "django_secret_key_arn" {
  description = "Name or ARN of the AWS Secrets Manager secret containing Django SECRET_KEY. Accepts: secret name (/path/to/secret), partial ARN (without suffix), or full ARN. The full ARN is looked up automatically for IAM policies."
  type        = string
}

variable "django_allowed_hosts" {
  description = "Comma-separated list of allowed hosts for Django (e.g., 'api.lightwave-media.ltd,*.amazonaws.com')"
  type        = string
}

variable "database_url" {
  description = "Database connection string in URL format (postgresql://user:pass@host:port/dbname)"
  type        = string
  sensitive   = true
}

variable "redis_url" {
  description = "Redis connection URL for caching and Celery broker (redis://host:port/db)"
  type        = string
  sensitive   = true
  default     = null
}

variable "debug" {
  description = "Enable Django DEBUG mode (should be false in production)"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (e.g., 'production', 'staging', 'development')"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region for services (CloudWatch, S3, etc.)"
  type        = string
  default     = "us-east-1"
}

variable "celery_broker_url" {
  description = "Celery broker URL (defaults to redis_url if not specified)"
  type        = string
  sensitive   = true
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "service_sg_id" {
  description = "The ID of the security group for the ECS service. If null, one will be created."
  type        = string
  default     = null
}

variable "alb_sg_id" {
  description = "The ID of the security group for the ALB. If null, one will be created."
  type        = string
  default     = null
}

variable "cpu_architecture" {
  description = "The CPU architecture for the service (X86_64 or ARM64)"
  type        = string
  default     = "ARM64"
}

variable "health_check_path" {
  description = "Health check endpoint path for ALB target group"
  type        = string
  default     = "/health/live/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful health checks required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed health checks before marking unhealthy"
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

variable "additional_environment_variables" {
  description = "Additional environment variables to pass to the Django container"
  type        = map(string)
  default     = {}
}

variable "task_role_arn" {
  description = "ARN of the IAM role for the ECS task (for application-level AWS access). If null, a basic role will be created."
  type        = string
  default     = null
}
