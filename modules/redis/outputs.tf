output "primary_endpoint_address" {
  description = "The address of the primary endpoint for the replication group (read/write)"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "reader_endpoint_address" {
  description = "The address of the endpoint for the reader node in the replication group (read-only)"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "port" {
  description = "The port number on which the Redis cluster accepts connections"
  value       = aws_elasticache_replication_group.redis.port
}

output "arn" {
  description = "The ARN of the ElastiCache Replication Group"
  value       = aws_elasticache_replication_group.redis.arn
}

output "id" {
  description = "The ID of the ElastiCache Replication Group"
  value       = aws_elasticache_replication_group.redis.id
}

output "redis_security_group_id" {
  description = "The ID of the security group attached to the Redis cluster"
  value       = aws_security_group.redis.id
}

output "member_clusters" {
  description = "The identifiers of all the nodes that are part of this replication group"
  value       = aws_elasticache_replication_group.redis.member_clusters
}

output "configuration_endpoint_address" {
  description = "The address of the replication group configuration endpoint (for cluster mode only)"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

output "redis_url" {
  description = "Redis connection URL for Django CACHES configuration"
  value       = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}/0"
}

output "redis_url_with_auth" {
  description = "Redis connection URL with AUTH token (if auth_token_enabled)"
  value       = var.auth_token_enabled ? "redis://:${var.auth_token}@${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}/0" : null
  sensitive   = true
}

output "celery_broker_url" {
  description = "Redis connection URL formatted for Celery broker (uses DB 1 to avoid conflicts with cache)"
  value       = "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}/1"
}

output "celery_broker_url_with_auth" {
  description = "Redis connection URL formatted for Celery broker with AUTH token"
  value       = var.auth_token_enabled ? "redis://:${var.auth_token}@${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}/1" : null
  sensitive   = true
}
