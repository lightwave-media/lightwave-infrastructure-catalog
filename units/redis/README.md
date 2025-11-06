# Redis Unit

This unit provisions a production-ready Redis cluster using the `redis` module.

## Usage

### Production Configuration

```yaml
# config/redis.yaml
name: "lightwave-django-prod"
node_type: "cache.t4g.small"
subnet_ids:
  - "subnet-abc123"
  - "subnet-def456"

# Production settings
environment: "prod"
num_cache_clusters: 2
automatic_failover_enabled: true
multi_az_enabled: true
snapshot_retention_limit: 30

tags:
  Application: "Django API"
  Environment: "production"
  CostCenter: "engineering"
```

### Development Configuration

```yaml
# config/redis-dev.yaml
name: "lightwave-django-dev"
node_type: "cache.t4g.micro"
subnet_ids:
  - "subnet-abc123"

# Development settings
environment: "dev"
num_cache_clusters: 1
automatic_failover_enabled: false
multi_az_enabled: false
snapshot_retention_limit: 1

tags:
  Application: "Django API"
  Environment: "development"
```

## Inputs

All inputs from the `redis` module are supported. See [module documentation](../../modules/redis/README.md).

## Outputs

- `primary_endpoint_address` - Redis primary endpoint (read/write)
- `redis_url` - Full connection URL for Django CACHES
- `celery_broker_url` - Connection URL for Celery broker
- `redis_security_group_id` - Security group ID (for allowing access from Django)

## Deployment

```bash
# Deploy production Redis cluster
cd units/redis
terragrunt apply

# Get connection URLs
terragrunt output redis_url
terragrunt output celery_broker_url
```

## Post-Deployment

### Allow Django Service Access

```hcl
# In Django ECS service configuration
resource "aws_security_group_rule" "django_to_redis" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = dependency.redis.outputs.redis_security_group_id
  source_security_group_id = aws_security_group.django_service.id
}
```

### Store Connection Details in Secrets Manager

```bash
# After deployment
REDIS_URL=$(terragrunt output -raw redis_url)
CELERY_BROKER_URL=$(terragrunt output -raw celery_broker_url)

aws secretsmanager put-secret-value \
  --secret-id /lightwave/prod/django/redis-url \
  --secret-string "$REDIS_URL"

aws secretsmanager put-secret-value \
  --secret-id /lightwave/prod/django/celery-broker-url \
  --secret-string "$CELERY_BROKER_URL"
```

## Monitoring

Access CloudWatch logs:
```bash
# Slow log (queries > 10ms)
aws logs tail /aws/elasticache/lightwave-django-prod/slow-log --follow

# Engine log
aws logs tail /aws/elasticache/lightwave-django-prod/engine-log --follow
```

View metrics in CloudWatch:
- ElastiCache → Redis clusters → lightwave-django-prod → Monitoring

## Example Integration with Django Unit

```hcl
# units/django-fargate-stateful-service/terragrunt.hcl

dependency "redis" {
  config_path = "../redis"
  mock_outputs = {
    redis_url                = "redis://localhost:6379/0"
    celery_broker_url        = "redis://localhost:6379/1"
    redis_security_group_id  = "sg-12345"
  }
}

inputs = {
  redis_url         = dependency.redis.outputs.redis_url
  celery_broker_url = dependency.redis.outputs.celery_broker_url

  # Allow Django to access Redis
  additional_security_group_rules = [{
    type                     = "ingress"
    from_port                = 6379
    to_port                  = 6379
    protocol                 = "tcp"
    security_group_id        = dependency.redis.outputs.redis_security_group_id
    source_security_group_id = local.django_security_group_id
  }]
}
```

## Testing Redis Connection

```bash
# From Django container
python manage.py shell

# Test cache
from django.core.cache import cache
cache.set('test', 'hello', 300)
print(cache.get('test'))  # Should output: hello

# Test Celery connection
from celery import Celery
app = Celery('test', broker=os.environ['CELERY_BROKER_URL'])
print(app.connection().connect())  # Should succeed
```

## Troubleshooting

### Connection Timeout
- Check security group rules allow inbound on port 6379
- Verify Redis cluster is in same VPC as Django service
- Check VPC subnets have route to NAT Gateway (if using private subnets)

### Memory Issues
- Monitor `DatabaseMemoryUsagePercentage` metric
- Review `Evictions` metric (should be low)
- Consider upgrading node type if consistently high memory usage

### High Latency
- Check `CacheHits` vs `CacheMisses` ratio
- Review slow-log for queries > 10ms
- Consider adding read replicas (increase `num_cache_clusters`)

## Performance Tuning

### For Django Sessions + Cache
```yaml
maxmemory_policy: "volatile-lru"  # Only evict keys with TTL
```

### For Pure Cache (No Sessions)
```yaml
maxmemory_policy: "allkeys-lru"  # Evict any key (default)
```

### For Celery Only
```yaml
maxmemory_policy: "noeviction"  # Never evict, return errors instead
```
