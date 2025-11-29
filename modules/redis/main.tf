# ---------------------------------------------------------------------------------------------------------------------
# CREATE A REDIS CLUSTER (ElastiCache)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = var.name
  description          = "Redis cluster for ${var.name}"

  # Engine configuration
  engine               = "redis"
  engine_version       = var.engine_version
  port                 = var.port
  parameter_group_name = var.parameter_group_name != null ? var.parameter_group_name : aws_elasticache_parameter_group.redis[0].name

  # Node configuration
  node_type          = var.node_type
  num_cache_clusters = var.num_cache_clusters

  # Availability and failover
  automatic_failover_enabled = var.automatic_failover_enabled
  multi_az_enabled           = var.multi_az_enabled

  # Security
  security_group_ids         = [aws_security_group.redis.id]
  at_rest_encryption_enabled = var.at_rest_encryption_enabled
  transit_encryption_enabled = var.transit_encryption_enabled
  auth_token                 = var.auth_token_enabled ? var.auth_token : null

  # Subnet configuration
  subnet_group_name = aws_elasticache_subnet_group.redis.name

  # Maintenance and backups
  maintenance_window         = var.maintenance_window
  snapshot_window            = var.snapshot_window
  snapshot_retention_limit   = var.snapshot_retention_limit
  auto_minor_version_upgrade = var.auto_minor_version_upgrade

  # Notifications
  notification_topic_arn = var.notification_topic_arn

  # CloudWatch logs
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(
    var.tags,
    {
      Name        = var.name
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PARAMETER GROUP FOR REDIS (Django-optimized)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elasticache_parameter_group" "redis" {
  count = var.parameter_group_name == null ? 1 : 0

  name   = "${var.name}-redis-pg"
  family = var.parameter_group_family

  # Django session/cache optimization
  parameter {
    name  = "maxmemory-policy"
    value = var.maxmemory_policy
  }

  parameter {
    name  = "timeout"
    value = var.timeout
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  parameter {
    name  = "maxmemory-samples"
    value = "5"
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-redis-pg"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE SUBNET GROUP FOR REDIS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.name}-redis-subnet"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-redis-subnet"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECURITY GROUP FOR REDIS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis"
  description = "Security group for ${var.name} Redis cluster"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-redis"
      Environment = var.environment
    }
  )
}

module "allow_outbound_all" {
  source = "../sg-rule"

  security_group_id = aws_security_group.redis.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE CLOUDWATCH LOG GROUPS FOR REDIS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${var.name}/slow-log"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-slow-log"
      Environment = var.environment
    }
  )
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${var.name}/engine-log"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-engine-log"
      Environment = var.environment
    }
  )
}
