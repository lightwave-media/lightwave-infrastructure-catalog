# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the Redis cluster"
  type        = string
}

variable "node_type" {
  description = "The instance class to use for Redis nodes (e.g. cache.t4g.micro)"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where Redis nodes will be placed"
  type        = list(string)
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Cluster Configuration
# ---------------------------------------------------------------------------------------------------------------------

variable "engine_version" {
  description = "The version of Redis to run. https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/supported-engine-versions.html"
  type        = string
  default     = "7.1"
}

variable "port" {
  description = "The port number on which the Redis cluster accepts connections"
  type        = number
  default     = 6379
}

variable "num_cache_clusters" {
  description = "Number of cache clusters (nodes). Minimum 2 for Multi-AZ. For production: 2 = 1 primary + 1 replica"
  type        = number
  default     = 2
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - High Availability
# ---------------------------------------------------------------------------------------------------------------------

variable "automatic_failover_enabled" {
  description = "Specifies whether automatic failover is enabled. Required for Multi-AZ."
  type        = bool
  default     = true
}

variable "multi_az_enabled" {
  description = "Specifies whether Multi-AZ is enabled. Requires num_cache_clusters >= 2"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Security
# ---------------------------------------------------------------------------------------------------------------------

variable "at_rest_encryption_enabled" {
  description = "Whether to enable encryption at rest"
  type        = bool
  default     = true
}

variable "transit_encryption_enabled" {
  description = "Whether to enable encryption in transit (TLS)"
  type        = bool
  default     = true
}

variable "auth_token_enabled" {
  description = "Whether to use Redis AUTH token for authentication. Required when transit_encryption_enabled = true"
  type        = bool
  default     = false
}

variable "auth_token" {
  description = "The password used to access a password protected server. Required if auth_token_enabled = true"
  type        = string
  sensitive   = true
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Maintenance and Backups
# ---------------------------------------------------------------------------------------------------------------------

variable "maintenance_window" {
  description = "The weekly time range for system maintenance (UTC). Example: sun:05:00-sun:09:00"
  type        = string
  default     = "sun:05:00-sun:06:00"
}

variable "snapshot_window" {
  description = "The daily time range during which automated backups are created (UTC). Example: 03:00-05:00"
  type        = string
  default     = "03:00-04:00"
}

variable "snapshot_retention_limit" {
  description = "The number of days to retain automatic snapshots. 0 = disabled. Recommended: 7 for production"
  type        = number
  default     = 7
}

variable "auto_minor_version_upgrade" {
  description = "Specifies whether minor engine upgrades are applied automatically during maintenance window"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Parameter Group (Django-optimized defaults)
# ---------------------------------------------------------------------------------------------------------------------

variable "parameter_group_name" {
  description = "Name of an existing parameter group to use. If null, a new parameter group will be created."
  type        = string
  default     = null
}

variable "parameter_group_family" {
  description = "The family of the parameter group (e.g. redis7, redis6.x)"
  type        = string
  default     = "redis7"
}

variable "maxmemory_policy" {
  description = "Redis eviction policy when maxmemory is reached. Options: volatile-lru, allkeys-lru, volatile-lfu, allkeys-lfu, volatile-random, allkeys-random, volatile-ttl, noeviction. Recommended for Django cache: allkeys-lru"
  type        = string
  default     = "allkeys-lru"
}

variable "timeout" {
  description = "Close connection after client idle for N seconds (0 = disable)"
  type        = string
  default     = "300"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Monitoring
# ---------------------------------------------------------------------------------------------------------------------

variable "notification_topic_arn" {
  description = "ARN of SNS topic for ElastiCache notifications"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 7
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Tags
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default     = {}
}
