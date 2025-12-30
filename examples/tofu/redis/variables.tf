variable "name" {
  description = "The name of the Redis cluster"
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "node_type" {
  description = "The instance class to use for Redis nodes"
  type        = string
  default     = "cache.t4g.micro"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "automatic_failover" {
  description = "Whether automatic failover is enabled"
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "Whether Multi-AZ is enabled"
  type        = bool
  default     = false
}

variable "auth_token_enabled" {
  description = "Whether to enable Redis AUTH token"
  type        = bool
  default     = false
}
