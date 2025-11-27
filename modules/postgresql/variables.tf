# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the DB (used for resource naming, can contain hyphens)"
  type        = string
}

variable "db_name" {
  description = "The name of the database to create (must be alphanumeric only, no hyphens). If not provided, defaults to 'name' with hyphens removed."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "The instance class of the DB (e.g. db.t4g.micro)"
  type        = string
}

variable "allocated_storage" {
  description = "The amount of space, in GB, to allocate for the DB"
  type        = number
}

variable "storage_type" {
  description = "The type of storage to use for the DB. Must be one of: standard, gp2, gp3, or io1."
  type        = string
  default     = "gp3"
}

variable "master_username" {
  description = "The username for the master user of the DB"
  type        = string
  sensitive   = true
}

variable "master_password" {
  description = "The password for the master user of the DB"
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Production Features
# ---------------------------------------------------------------------------------------------------------------------

variable "engine_version" {
  description = "The version of PostgreSQL to run. https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts"
  type        = string
  default     = "15.10"
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "multi_az" {
  description = "If true, the DB instance will be Multi-AZ (high availability)"
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "The number of days to retain automated backups. Set to 0 to disable backups. Recommended: 7-35 for production."
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "The daily time range during which automated backups are created (UTC). Example: 09:46-10:16"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "The weekly time range during which maintenance can occur (UTC). Example: Mon:00:00-Mon:03:00"
  type        = string
  default     = "Sun:04:00-Sun:05:00"
}

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "The ARN for the KMS encryption key. If not specified, AWS managed key is used."
  type        = string
  default     = null
}

variable "max_allocated_storage" {
  description = "The upper limit (GB) to which RDS can automatically scale storage. 0 = disabled. Recommended: allocated_storage * 5"
  type        = number
  default     = 100
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch Logs. Valid values: postgresql, upgrade."
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights (useful for query optimization)"
  type        = bool
  default     = true
}

variable "performance_insights_retention_period" {
  description = "The amount of time in days to retain Performance Insights data. Valid values: 7, 731"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "If true, the database cannot be deleted. Should be true for production."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "If set to true, skip the final snapshot of the DB when it is being deleted. In production, this should always be false. Only set it to true for automated testing."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Parameter Group (Django-optimized defaults)
# ---------------------------------------------------------------------------------------------------------------------

variable "parameter_group_name" {
  description = "Name of an existing DB parameter group to use. If null, a new parameter group will be created."
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "The family of the DB parameter group (e.g. postgres15, postgres16)"
  type        = string
  default     = "postgres15"
}

variable "shared_buffers" {
  description = "PostgreSQL shared_buffers parameter (in 8KB pages). Recommended: 25% of instance RAM."
  type        = string
  default     = "32768" # 256MB for t4g.micro
}

variable "max_connections" {
  description = "PostgreSQL max_connections parameter. Recommended: CPU cores * 2 + effective_spindle_count"
  type        = string
  default     = "100"
}

variable "work_mem" {
  description = "PostgreSQL work_mem parameter (in KB). Memory used for sorting/hashing per operation."
  type        = string
  default     = "4096" # 4MB
}

variable "maintenance_work_mem" {
  description = "PostgreSQL maintenance_work_mem parameter (in KB). Memory for VACUUM, CREATE INDEX, etc."
  type        = string
  default     = "65536" # 64MB
}

variable "effective_cache_size" {
  description = "PostgreSQL effective_cache_size parameter (in 8KB pages). Hint for query planner about OS cache size."
  type        = string
  default     = "131072" # 1GB
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Networking
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for RDS deployment (must be in at least 2 AZs for Multi-AZ)"
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Tags
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
