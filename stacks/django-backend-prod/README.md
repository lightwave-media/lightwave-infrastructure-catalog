# Django Backend Production Stack

Complete production-ready Django backend infrastructure deployed as a single orchestrated stack.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Cloudflare (api.lightwave-media.ltd)                        │
│  - DDoS Protection                                           │
│  - WAF (Web Application Firewall)                           │
│  - SSL/TLS                                                   │
│  - Caching                                                   │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ Application Load Balancer                                    │
│  - Health Checks                                             │
│  - Target Group                                              │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│ ECS Fargate (2 containers)                                   │
│  - Django 5.0+ REST Framework                                │
│  - Gunicorn WSGI server                                      │
│  - Auto-scaling                                              │
│  - CloudWatch Logs                                           │
└───────────┬─────────────────────┬───────────────────────────┘
            │                     │
            ▼                     ▼
┌───────────────────────┐  ┌──────────────────────────────────┐
│ RDS PostgreSQL        │  │ ElastiCache Redis                │
│  - Multi-AZ           │  │  - Multi-AZ replication          │
│  - Auto backups       │  │  - Automatic failover            │
│  - Encryption         │  │  - Cache + Celery broker         │
└───────────────────────┘  └──────────────────────────────────┘
```

## Components

| Component | Purpose | Size | Monthly Cost |
|-----------|---------|------|--------------|
| PostgreSQL | Database | db.t4g.small (50 GB) | ~$28 |
| Redis | Cache + Celery | cache.t4g.small | ~$24 |
| ECS Fargate | Compute | 2x (0.5 vCPU, 1 GB) | ~$30 |
| ALB | Load balancing | - | ~$18 |
| Cloudflare | DNS + CDN | - | Free |
| **Total** | - | - | **~$100/month** |

## Prerequisites

### 1. AWS Resources

```bash
# VPC and Subnets (existing or create new)
export VPC_ID="vpc-abc123"
export PRIVATE_SUBNET_IDS="subnet-abc123,subnet-def456"
export PUBLIC_SUBNET_IDS="subnet-ghi789,subnet-jkl012"

# ECR Repository with Docker image
export ECR_REPOSITORY_URL="123456789012.dkr.ecr.us-east-1.amazonaws.com/lightwave-django"
export IMAGE_TAG="prod"

# Django SECRET_KEY in Secrets Manager
export DJANGO_SECRET_KEY_ARN="arn:aws:secretsmanager:us-east-1:123456789012:secret:/lightwave/prod/django/secret-key"

# Database credentials
export DB_MASTER_USERNAME="postgres"
export DB_MASTER_PASSWORD="your-secure-password"

# Django allowed hosts
export DJANGO_ALLOWED_HOSTS="api.lightwave-media.ltd,*.amazonaws.com"
```

### 2. Cloudflare Credentials

```bash
# Cloudflare API token (with DNS edit permissions)
export CLOUDFLARE_API_TOKEN="your-api-token"

# Cloudflare Zone ID for lightwave-media.ltd
export CLOUDFLARE_ZONE_ID="your-zone-id"
```

### 3. Store Secrets in AWS Secrets Manager

```bash
# Django SECRET_KEY
aws secretsmanager create-secret \
  --name /lightwave/prod/django/secret-key \
  --secret-string "$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')"

# Cloudflare credentials
aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-api-token \
  --secret-string "your-cloudflare-api-token"

aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-zone-id \
  --secret-string "your-cloudflare-zone-id"
```

## Deployment

### Step 1: Build and Push Docker Image

```bash
# Navigate to Django source
cd ../../units/django-fargate-stateful-service/src

# Build for ARM64 (Fargate graviton)
docker build --platform linux/arm64 -t lightwave-django:prod .

# Tag and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL
docker tag lightwave-django:prod $ECR_REPOSITORY_URL:prod
docker push $ECR_REPOSITORY_URL:prod
```

### Step 2: Load Environment Variables

```bash
# Option 1: Export manually
export VPC_ID="vpc-abc123"
export PRIVATE_SUBNET_IDS="subnet-abc123,subnet-def456"
# ... (all variables from Prerequisites section)

# Option 2: Load from .env file
set -a
source .env.prod
set +a

# Option 3: Load from Secrets Manager
export CLOUDFLARE_API_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id /lightwave/prod/cloudflare-api-token \
  --query SecretString --output text)
```

### Step 3: Deploy Stack

```bash
# Navigate to stack directory
cd stacks/django-backend-prod

# Preview changes
terragrunt stack plan

# Deploy all components
terragrunt stack apply

# This will:
# 1. Create PostgreSQL database (Multi-AZ)
# 2. Create Redis cluster (Multi-AZ)
# 3. Deploy Django containers to ECS
# 4. Create Cloudflare DNS record
# 5. Wait for health checks to pass
```

### Step 4: Verify Deployment

```bash
# Check DNS resolution
dig api.lightwave-media.ltd

# Test liveness endpoint
curl https://api.lightwave-media.ltd/health/live/

# Expected output:
# {"status": "ok", "service": "django-api"}

# Test readiness endpoint
curl https://api.lightwave-media.ltd/health/ready/

# Expected output:
# {"status": "healthy", "checks": {"database": true, "cache": true}}
```

## Post-Deployment

### Run Django Migrations

```bash
# Get ECS task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster lightwave-django-prod \
  --query 'taskArns[0]' --output text)

# Run migrations via ECS Exec
aws ecs execute-command \
  --cluster lightwave-django-prod \
  --task $TASK_ARN \
  --container django \
  --interactive \
  --command "python manage.py migrate"
```

### Create Django Superuser

```bash
# Same process as migrations
aws ecs execute-command \
  --cluster lightwave-django-prod \
  --task $TASK_ARN \
  --container django \
  --interactive \
  --command "python manage.py createsuperuser"
```

### Collect Static Files (if using S3)

```bash
aws ecs execute-command \
  --cluster lightwave-django-prod \
  --task $TASK_ARN \
  --container django \
  --interactive \
  --command "python manage.py collectstatic --noinput"
```

## Monitoring

### CloudWatch Logs

```bash
# Django application logs
aws logs tail /ecs/lightwave-django-prod --follow

# PostgreSQL logs
aws logs tail /aws/rds/instance/lightwave-django-prod/postgresql --follow

# Redis slow log
aws logs tail /aws/elasticache/lightwave-django-prod/slow-log --follow
```

### CloudWatch Metrics

Key metrics to monitor:
- **ECS**: CPUUtilization, MemoryUtilization, HealthyHostCount
- **RDS**: DatabaseConnections, CPUUtilization, FreeStorageSpace
- **Redis**: CacheHits, CacheMisses, CPUUtilization, EngineCPUUtilization
- **ALB**: TargetResponseTime, HTTPCode_Target_2XX_Count, HTTPCode_Target_5XX_Count

### Cloudflare Analytics

Access via Cloudflare Dashboard:
- Requests per second
- Bandwidth usage
- Cache hit ratio
- Security threats blocked

## Scaling

### Horizontal Scaling (Add More Containers)

```bash
# Edit stack config
desired_count = 4  # Increase from 2 to 4

# Apply changes
terragrunt stack apply
```

### Vertical Scaling (Increase Container Size)

```bash
# Edit stack config
cpu    = 1024  # Increase from 512
memory = 2048  # Increase from 1024

terragrunt stack apply
```

### Database Scaling

```bash
# Edit stack config
instance_class = "db.t4g.medium"  # Upgrade from db.t4g.small

terragrunt stack apply
```

## Disaster Recovery

### Database Backups

Automated backups occur daily with 30-day retention.

**Manual snapshot**:
```bash
aws rds create-db-snapshot \
  --db-instance-identifier lightwave-django-prod \
  --db-snapshot-identifier lightwave-django-prod-$(date +%Y%m%d)
```

**Restore from snapshot**:
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier lightwave-django-prod-restored \
  --db-snapshot-identifier lightwave-django-prod-20250128
```

### Redis Backups

Automated snapshots occur daily with 30-day retention.

**Manual snapshot**:
```bash
aws elasticache create-snapshot \
  --replication-group-id lightwave-django-prod \
  --snapshot-name lightwave-django-prod-$(date +%Y%m%d)
```

## Cleanup

```bash
# Destroy entire stack
cd stacks/django-backend-prod
terragrunt stack destroy

# This will destroy (in order):
# 1. Cloudflare DNS record
# 2. Django ECS service
# 3. Redis cluster
# 4. PostgreSQL database (if deletion_protection = false)
```

**Warning**: If `deletion_protection = true` on database, you must disable it first:

```bash
aws rds modify-db-instance \
  --db-instance-identifier lightwave-django-prod \
  --no-deletion-protection
```

## Troubleshooting

### Stack Apply Failed

Check which unit failed:
```bash
terragrunt stack plan
```

Apply individual unit:
```bash
cd ../../units/postgresql
terragrunt apply
```

### Database Connection Errors

1. Check security group rules
2. Verify DATABASE_URL in task definition
3. Check database endpoint is correct
4. Test connection from ECS task

### Redis Connection Errors

1. Check security group rules
2. Verify REDIS_URL in task definition
3. Check Redis cluster is in same VPC
4. Test connection from ECS task

### Cloudflare DNS Not Resolving

1. Verify CLOUDFLARE_API_TOKEN is valid
2. Check zone_id is correct
3. Verify nameservers point to Cloudflare
4. Wait for DNS propagation (up to 5 minutes)

## Cost Optimization

1. **Use ARM64 instances** (t4g) - 20% cheaper than t3
2. **Enable auto-scaling** - Scale down during low traffic
3. **Use gp3 storage** - Cheaper than gp2
4. **Enable storage auto-scaling** - Only pay for what you use
5. **Use Reserved Instances** (for long-term production)

## Security Best Practices

1. **Secrets Manager** for all credentials
2. **Private subnets** for database and Redis
3. **Security groups** with least-privilege rules
4. **Encryption** at rest and in transit
5. **Cloudflare WAF** for DDoS protection
6. **Regular security updates** via auto minor version upgrades
7. **Audit logs** via CloudWatch
8. **MFA** on AWS account

## Next Steps

1. Configure auto-scaling policies
2. Set up CloudWatch alarms
3. Create backup strategy
4. Configure WAF rules in Cloudflare
5. Set up CI/CD pipeline
6. Configure monitoring dashboards

## Support

For issues or questions:
- Check CloudWatch logs first
- Review AWS Console for resource health
- Check Cloudflare dashboard for DNS/SSL issues
- Verify all environment variables are set correctly
