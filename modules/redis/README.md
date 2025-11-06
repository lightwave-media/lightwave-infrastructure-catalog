# Redis Module

This module provisions a production-ready Amazon ElastiCache Redis cluster with Django-optimized configuration.

## Features

- **High Availability**: Multi-AZ replication with automatic failover
- **Security**: Encryption at rest and in transit, VPC security groups, optional AUTH token
- **Backups**: Automated daily snapshots with configurable retention
- **Performance**: Redis 7.x engine, SSD storage, connection pooling
- **Monitoring**: CloudWatch logs for slow queries and engine events
- **Django-optimized**: Parameter group tuned for Django cache and Celery

## Usage

```hcl
module "redis" {
  source = "../../modules/redis"

  name       = "my-django-cache"
  node_type  = "cache.t4g.micro"
  subnet_ids = var.private_subnet_ids

  # Production settings
  environment                = "prod"
  num_cache_clusters         = 2  # 1 primary + 1 replica
  automatic_failover_enabled = true
  multi_az_enabled           = true
  snapshot_retention_limit   = 7

  tags = {
    Application = "Django API"
    Owner       = "Platform Team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Cluster name | string | - | yes |
| node_type | Instance class (e.g. cache.t4g.micro) | string | - | yes |
| subnet_ids | List of subnet IDs | list(string) | - | yes |
| engine_version | Redis version | string | 7.1 | no |
| num_cache_clusters | Number of nodes | number | 2 | no |
| automatic_failover_enabled | Enable auto-failover | bool | true | no |
| multi_az_enabled | Enable Multi-AZ | bool | true | no |
| at_rest_encryption_enabled | Enable encryption | bool | true | no |
| transit_encryption_enabled | Enable TLS | bool | true | no |
| auth_token_enabled | Enable AUTH token | bool | false | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| primary_endpoint_address | Primary endpoint (read/write) |
| reader_endpoint_address | Reader endpoint (read-only) |
| port | Redis port |
| redis_url | Full connection URL for Django |
| celery_broker_url | Connection URL for Celery |
| redis_security_group_id | Security group ID |

## Redis Configuration

This module creates a parameter group with Django-optimized settings:

- `maxmemory-policy`: `allkeys-lru` (evict least recently used keys)
- `timeout`: 300 seconds (close idle connections after 5 minutes)
- `tcp-keepalive`: 300 seconds
- `maxmemory-samples`: 5 (LRU sampling accuracy)

### Node Sizing Recommendations

| Environment | Node Type | vCPU | RAM | Cost/month |
|-------------|-----------|------|-----|------------|
| Dev/Test | cache.t4g.micro | 2 | 0.5 GB | $12 |
| Staging | cache.t4g.small | 2 | 1.37 GB | $24 |
| Production | cache.t4g.medium | 2 | 3.09 GB | $48 |
| High-traffic | cache.r6g.large | 2 | 13.07 GB | $120 |

## Security

- **Encryption at rest**: Enabled by default (AWS managed KMS key)
- **Encryption in transit**: Enabled by default (TLS 1.2+)
- **AUTH token**: Optional (recommended for production if TLS enabled)
- **Security groups**: Only accessible via explicit rules
- **VPC placement**: Private subnets only

## Connecting from Django

Use the `redis_url` output:

```python
# config/settings/prod.py
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.environ['REDIS_URL'],  # redis://host:port/0
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 50,
                'retry_on_timeout': True,
            },
        },
    }
}

# Celery broker
CELERY_BROKER_URL = os.environ['CELERY_BROKER_URL']  # redis://host:port/1
CELERY_RESULT_BACKEND = CELERY_BROKER_URL

# Django sessions (optional)
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'
SESSION_CACHE_ALIAS = 'default'
```

## Database Separation

This module outputs separate URLs for different use cases:

- **`redis_url`**: Django cache (DB 0)
- **`celery_broker_url`**: Celery task queue (DB 1)

This ensures cache flushes don't affect Celery tasks.

## Backup and Restore

Automated snapshots occur during `snapshot_window` (default: 03:00-04:00 UTC).

Manual snapshot:
```bash
aws elasticache create-snapshot \
  --replication-group-id my-django-cache \
  --snapshot-name my-django-cache-manual-2025-01-01
```

Restore from snapshot:
```bash
aws elasticache create-replication-group \
  --replication-group-id my-django-cache-restored \
  --snapshot-name my-django-cache-manual-2025-01-01
```

## Monitoring

CloudWatch metrics available:
- `CPUUtilization`
- `CacheHits` / `CacheMisses`
- `EngineCPUUtilization`
- `NetworkBytesIn` / `NetworkBytesOut`
- `CurrConnections`
- `Evictions`
- `DatabaseMemoryUsagePercentage`

CloudWatch logs:
- `/aws/elasticache/{name}/slow-log` - Slow queries (>10ms)
- `/aws/elasticache/{name}/engine-log` - Engine events

## High Availability

With `multi_az_enabled = true` and `num_cache_clusters = 2`:

- **Primary node**: Handles all writes and reads
- **Replica node**: Handles reads, automatic promotion on primary failure
- **Failover time**: ~1-2 minutes
- **Data loss**: Minimal (asynchronous replication)

## Scaling

**Vertical scaling** (upgrade node size):
```hcl
module "redis" {
  node_type = "cache.t4g.small"  # Changed from cache.t4g.micro
}
```

**Horizontal scaling** (add more replicas):
```hcl
module "redis" {
  num_cache_clusters = 3  # 1 primary + 2 replicas
}
```

## Example: Production Configuration

```hcl
module "redis_prod" {
  source = "../../modules/redis"

  name       = "lightwave-django-prod"
  node_type  = "cache.t4g.small"
  subnet_ids = data.aws_subnets.private.ids

  environment                = "prod"
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token_enabled         = false  # Enable if using AUTH

  # Backups
  snapshot_retention_limit = 30
  snapshot_window          = "03:00-04:00"

  # Performance tuning
  maxmemory_policy = "allkeys-lru"
  timeout          = "300"

  # Monitoring
  notification_topic_arn = aws_sns_topic.alerts.arn
  log_retention_days     = 30

  tags = {
    Application = "LightWave Django API"
    Environment = "production"
    Owner       = "Platform Team"
    CostCenter  = "engineering"
  }
}
```

## Testing

Run module validation:
```bash
cd examples/tofu/redis
tofu init
tofu plan
```

Run Terratest:
```bash
cd test
go test -v -timeout 30m -run TestRedisModule
```

## Troubleshooting

### Connection Timeout
- Check security group rules allow inbound on port 6379
- Verify client is in same VPC
- Check if `transit_encryption_enabled = true` (use `rediss://` URL)

### High Memory Usage
- Review `maxmemory-policy` setting
- Monitor `Evictions` metric
- Consider upgrading node size

### Cache Miss Rate High
- Review cache TTL settings in Django
- Consider pre-warming cache on deployment
- Increase node size if evictions are high

## References

- [AWS ElastiCache for Redis Documentation](https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/)
- [Django Redis Documentation](https://github.com/jazzband/django-redis)
- [Celery Redis Backend](https://docs.celeryproject.org/en/stable/getting-started/backends-and-brokers/redis.html)
