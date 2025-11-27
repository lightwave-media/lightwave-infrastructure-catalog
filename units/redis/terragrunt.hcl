include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/redis?ref=${try(values.version, "main")}"
}

inputs = {
  # Required inputs
  name       = values.name
  node_type  = values.node_type
  subnet_ids = values.subnet_ids
  vpc_id     = values.vpc_id

  # Optional inputs - Production defaults
  engine_version = try(values.engine_version, "7.1")
  port           = try(values.port, 6379)
  environment    = try(values.environment, "prod")

  # High availability
  num_cache_clusters         = try(values.num_cache_clusters, 2) # 1 primary + 1 replica
  automatic_failover_enabled = try(values.automatic_failover_enabled, true)
  multi_az_enabled           = try(values.multi_az_enabled, true)

  # Security
  at_rest_encryption_enabled = try(values.at_rest_encryption_enabled, true)
  transit_encryption_enabled = try(values.transit_encryption_enabled, true)
  auth_token_enabled         = try(values.auth_token_enabled, false)
  auth_token                 = try(values.auth_token, null)

  # Maintenance and backups
  maintenance_window         = try(values.maintenance_window, "sun:05:00-sun:06:00")
  snapshot_window            = try(values.snapshot_window, "03:00-04:00")
  snapshot_retention_limit   = try(values.snapshot_retention_limit, 7)
  auto_minor_version_upgrade = try(values.auto_minor_version_upgrade, true)

  # Parameter group
  parameter_group_name   = try(values.parameter_group_name, null)
  parameter_group_family = try(values.parameter_group_family, "redis7")
  maxmemory_policy       = try(values.maxmemory_policy, "allkeys-lru")
  timeout                = try(values.timeout, "300")

  # Monitoring
  notification_topic_arn = try(values.notification_topic_arn, null)
  log_retention_days     = try(values.log_retention_days, 7)

  # Tags
  tags = try(values.tags, {})
}
