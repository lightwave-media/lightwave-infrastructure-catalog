include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/postgresql"
}

inputs = {
  # Required inputs
  name              = values.name
  instance_class    = values.instance_class
  allocated_storage = values.allocated_storage
  master_username   = values.master_username
  master_password   = values.master_password

  # Optional inputs - Production defaults
  storage_type            = try(values.storage_type, "gp3")
  engine_version          = try(values.engine_version, "15.10")
  environment             = try(values.environment, "prod")
  multi_az                = try(values.multi_az, true)
  backup_retention_period = try(values.backup_retention_period, 7)
  deletion_protection     = try(values.deletion_protection, true)
  skip_final_snapshot     = try(values.skip_final_snapshot, false)

  # Storage auto-scaling
  max_allocated_storage = try(values.max_allocated_storage, values.allocated_storage * 5)

  # Performance
  performance_insights_enabled          = try(values.performance_insights_enabled, true)
  performance_insights_retention_period = try(values.performance_insights_retention_period, 7)

  # Security
  storage_encrypted = try(values.storage_encrypted, true)
  kms_key_id        = try(values.kms_key_id, null)

  # Monitoring
  enabled_cloudwatch_logs_exports = try(values.enabled_cloudwatch_logs_exports, ["postgresql", "upgrade"])

  # Maintenance windows
  backup_window      = try(values.backup_window, "03:00-04:00")
  maintenance_window = try(values.maintenance_window, "Sun:04:00-Sun:05:00")

  # Parameter group
  parameter_group_name   = try(values.parameter_group_name, null)
  parameter_group_family = try(values.parameter_group_family, "postgres15")

  # Django-optimized parameters
  shared_buffers       = try(values.shared_buffers, "32768") # 256MB for t4g.micro
  max_connections      = try(values.max_connections, "100")
  work_mem             = try(values.work_mem, "4096")               # 4MB
  maintenance_work_mem = try(values.maintenance_work_mem, "65536")  # 64MB
  effective_cache_size = try(values.effective_cache_size, "131072") # 1GB

  # Networking (REQUIRED for module)
  vpc_id     = values.vpc_id
  subnet_ids = values.subnet_ids

  # Tags
  tags = try(values.tags, {})
}
