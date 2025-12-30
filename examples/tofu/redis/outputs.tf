output "primary_endpoint_address" {
  description = "The address of the primary endpoint"
  value       = module.redis.primary_endpoint_address
}

output "port" {
  description = "The port number on which Redis accepts connections"
  value       = module.redis.port
}

output "arn" {
  description = "The ARN of the ElastiCache Replication Group"
  value       = module.redis.arn
}

output "redis_security_group_id" {
  description = "The ID of the security group attached to the Redis cluster"
  value       = module.redis.redis_security_group_id
}

output "redis_url" {
  description = "Redis connection URL for Django CACHES"
  value       = module.redis.redis_url
}

output "celery_broker_url" {
  description = "Redis connection URL for Celery broker"
  value       = module.redis.celery_broker_url
}
