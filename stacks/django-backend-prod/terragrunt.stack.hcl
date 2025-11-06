locals {
  environment = "prod"
}

# =============================================================================
# Django Backend Production Stack
# =============================================================================
#
# This stack deploys a complete production Django backend:
# 1. PostgreSQL RDS database (Multi-AZ)
# 2. Redis ElastiCache cluster (Multi-AZ, replication)
# 3. Django on ECS Fargate (auto-scaling, health checks)
# 4. Cloudflare DNS (DDoS protection, SSL, caching)
#
# Deployment order:
# 1. PostgreSQL + Redis (parallel)
# 2. Django service (depends on database + Redis)
# 3. Cloudflare DNS (depends on Django service ALB)
#
# Usage:
#   terragrunt stack plan
#   terragrunt stack apply
#   terragrunt stack destroy
# =============================================================================

# -----------------------------------------------------------------------------
# PostgreSQL Database
# -----------------------------------------------------------------------------
unit "postgresql" {
  path = "../../units/postgresql"

  inputs = {
    name              = "lightwave-django-${local.environment}"
    instance_class    = "db.t4g.small"
    allocated_storage = 50

    # Load master credentials from Secrets Manager
    master_username = get_env("DB_MASTER_USERNAME", "postgres")
    master_password = get_env("DB_MASTER_PASSWORD")

    # Networking - Deploy to database subnets in VPC
    vpc_id     = get_env("VPC_ID")
    subnet_ids = split(",", get_env("DB_SUBNET_IDS"))

    # Production settings
    environment             = local.environment
    multi_az                = true
    backup_retention_period = 30
    deletion_protection     = true
    skip_final_snapshot     = false

    # Storage auto-scaling
    max_allocated_storage = 250

    # Performance
    performance_insights_enabled = true

    # Tags
    tags = {
      Application = "Django API"
      Environment = local.environment
      ManagedBy   = "Terragrunt Stack"
      Stack       = "django-backend-prod"
    }
  }
}

# -----------------------------------------------------------------------------
# Redis Cache and Celery Broker
# -----------------------------------------------------------------------------
unit "redis" {
  path = "../../units/redis"

  inputs = {
    name       = "lightwave-django-${local.environment}"
    node_type  = "cache.t4g.small"
    subnet_ids = split(",", get_env("PRIVATE_SUBNET_IDS", ""))

    # Production settings
    environment                = local.environment
    num_cache_clusters         = 2 # 1 primary + 1 replica
    automatic_failover_enabled = true
    multi_az_enabled           = true

    # Backups
    snapshot_retention_limit = 30

    # Tags
    tags = {
      Application = "Django API"
      Environment = local.environment
      ManagedBy   = "Terragrunt Stack"
      Stack       = "django-backend-prod"
    }
  }
}

# -----------------------------------------------------------------------------
# Django ECS Fargate Service
# -----------------------------------------------------------------------------
unit "django_service" {
  path = "../../units/django-fargate-stateful-service"

  # Depends on database and Redis
  depends_on = ["postgresql", "redis"]

  inputs = {
    name               = "lightwave-django-${local.environment}"
    desired_count      = 2 # Production: 2 containers for HA
    cpu                = 512
    memory             = 1024
    ecr_repository_url = get_env("ECR_REPOSITORY_URL")
    image_tag          = get_env("IMAGE_TAG", "prod")

    # Django configuration
    django_secret_key_arn  = get_env("DJANGO_SECRET_KEY_ARN")
    django_settings_module = "config.settings.prod"
    django_allowed_hosts   = get_env("DJANGO_ALLOWED_HOSTS", "*.lightwave-media.ltd,*.amazonaws.com")

    # Database URL is provided by dependency
    # Redis URLs are provided by dependency

    # Environment
    environment = local.environment
    debug       = false
    aws_region  = get_env("AWS_REGION", "us-east-1")

    # Networking
    vpc_id             = get_env("VPC_ID")
    private_subnet_ids = split(",", get_env("PRIVATE_SUBNET_IDS", ""))
    public_subnet_ids  = split(",", get_env("PUBLIC_SUBNET_IDS", ""))

    # Health checks
    health_check_path                = "/health/live/"
    health_check_interval            = 30
    health_check_timeout             = 5
    health_check_healthy_threshold   = 2
    health_check_unhealthy_threshold = 3

    # Monitoring
    enable_container_insights     = true
    cloudwatch_log_retention_days = 30

    # Tags
    tags = {
      Application = "Django API"
      Environment = local.environment
      ManagedBy   = "Terragrunt Stack"
      Stack       = "django-backend-prod"
    }
  }
}

# -----------------------------------------------------------------------------
# Cloudflare DNS
# -----------------------------------------------------------------------------
unit "cloudflare_dns" {
  path = "../../units/cloudflare-dns"

  # Depends on Django service (needs ALB DNS name)
  depends_on = ["django_service"]

  inputs = {
    zone_id     = get_env("CLOUDFLARE_ZONE_ID")
    record_name = "api" # Creates api.lightwave-media.ltd
    proxied     = true  # Enable Cloudflare proxy

    # SSL/TLS
    configure_ssl_settings = true
    ssl_mode               = "full"
    min_tls_version        = "1.2"
    always_use_https       = "on"
    http3_enabled          = "on"

    # Caching (bypass for authenticated requests)
    create_cache_rule      = true
    bypass_cache_on_cookie = "session.*"

    # Metadata
    environment = local.environment
    comment     = "Django API production endpoint - Managed by Terragrunt Stack"

    # Tags
    tags = {
      Application = "Django API"
      Environment = local.environment
      ManagedBy   = "Terragrunt Stack"
      Stack       = "django-backend-prod"
    }
  }
}
