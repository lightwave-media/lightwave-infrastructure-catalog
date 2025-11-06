# Django Backend Production Deployment Guide

Complete guide for deploying production-ready Django REST Framework backend on AWS with automated Cloudflare DNS.

## 🎯 Quick Start (5 Minutes)

```bash
# 1. Set environment variables
export VPC_ID="vpc-abc123"
export PRIVATE_SUBNET_IDS="subnet-1,subnet-2"
export PUBLIC_SUBNET_IDS="subnet-3,subnet-4"
export ECR_REPOSITORY_URL="123456789012.dkr.ecr.us-east-1.amazonaws.com/lightwave-django"
export DJANGO_SECRET_KEY_ARN="arn:aws:secretsmanager:..."
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ZONE_ID="your-zone-id"
export DB_MASTER_PASSWORD="your-secure-password"

# 2. Run bootstrap script
./scripts/bootstrap-production.sh

# 3. Access your API
curl https://api.lightwave-media.ltd/health/ready/
```

## 📦 What Gets Deployed

| Resource | Configuration | Purpose |
|----------|---------------|---------|
| **PostgreSQL RDS** | db.t4g.small, Multi-AZ, 50 GB | Django database |
| **Redis ElastiCache** | cache.t4g.small, Multi-AZ, replication | Cache + Celery broker |
| **ECS Fargate** | 2 containers, 0.5 vCPU, 1 GB each | Django application |
| **Application Load Balancer** | HTTP/HTTPS, health checks | Load balancing |
| **Cloudflare DNS** | CNAME record, proxy enabled | CDN, DDoS, SSL |

**Monthly Cost**: ~$100 (Production configuration)

## 🏗️ Architecture

```
Internet
    ↓
Cloudflare (api.lightwave-media.ltd)
  - DDoS Protection
  - WAF
  - SSL/TLS
  - Caching
    ↓
AWS Application Load Balancer
    ↓
ECS Fargate (2 containers)
  - Django 5.0+
  - Gunicorn
  - Health checks
    ↓
┌─────────────┬──────────────┐
│             │              │
PostgreSQL    Redis
(Multi-AZ)    (Multi-AZ)
```

## 🔧 Modules Created

### 1. PostgreSQL Module (`modules/postgresql/`)
- RDS PostgreSQL 15+ with Multi-AZ
- Automated backups (30-day retention)
- Encryption at rest and in transit
- Performance Insights enabled
- CloudWatch logs exported
- Django-optimized parameter group

### 2. Redis Module (`modules/redis/`)
- ElastiCache Redis 7.x
- Multi-AZ replication (1 primary + 1 replica)
- Automatic failover
- Separate DB indices for cache (0) and Celery (1)
- CloudWatch slow query logs

### 3. Cloudflare DNS Module (`modules/cloudflare-dns/`)
- Automated CNAME record creation
- Proxy configuration (DDoS protection)
- SSL/TLS settings
- Optional caching rules
- Health check monitoring

## 📋 Prerequisites

### AWS Resources

#### 1. ECR Repository with Django Image

```bash
# Create ECR repository
aws ecr create-repository \
  --repository-name lightwave-django \
  --profile lightwave-admin-new

# Output: ECR_REPOSITORY_URL
# Example: 123456789012.dkr.ecr.us-east-1.amazonaws.com/lightwave-django
```

#### 2. VPC and Subnets

```bash
# Use existing VPC or create new
VPC_ID="vpc-abc123"

# Private subnets for database, Redis, ECS tasks
PRIVATE_SUBNET_IDS="subnet-abc123,subnet-def456"

# Public subnets for Application Load Balancer
PUBLIC_SUBNET_IDS="subnet-ghi789,subnet-jkl012"
```

#### 3. Secrets Manager

```bash
# Django SECRET_KEY
aws secretsmanager create-secret \
  --name /lightwave/prod/django/secret-key \
  --secret-string "$(python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')" \
  --profile lightwave-admin-new

# Get ARN (save this as DJANGO_SECRET_KEY_ARN)
aws secretsmanager describe-secret \
  --secret-id /lightwave/prod/django/secret-key \
  --query ARN --output text

# Cloudflare API token
aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-api-token \
  --secret-string "your-cloudflare-api-token" \
  --profile lightwave-admin-new

# Cloudflare Zone ID
aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-zone-id \
  --secret-string "your-cloudflare-zone-id" \
  --profile lightwave-admin-new
```

### Cloudflare Setup

#### 1. Create API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Select your zone (lightwave-media.ltd)
5. Copy token

#### 2. Get Zone ID

1. Go to https://dash.cloudflare.com
2. Select your domain (lightwave-media.ltd)
3. Scroll down to "API" section
4. Copy "Zone ID"

## 🚀 Deployment Steps

### Option 1: Automated Bootstrap Script (Recommended)

```bash
# Step 1: Set all environment variables
export VPC_ID="vpc-abc123"
export PRIVATE_SUBNET_IDS="subnet-1,subnet-2"
export PUBLIC_SUBNET_IDS="subnet-3,subnet-4"
export ECR_REPOSITORY_URL="123456789012.dkr.ecr.us-east-1.amazonaws.com/lightwave-django"
export DJANGO_SECRET_KEY_ARN="arn:aws:secretsmanager:us-east-1:123456789012:secret:/lightwave/prod/django/secret-key"
export CLOUDFLARE_API_TOKEN="your-token"
export CLOUDFLARE_ZONE_ID="your-zone-id"
export DB_MASTER_PASSWORD="your-secure-password"

# Optional (defaults provided)
export IMAGE_TAG="prod"
export AWS_REGION="us-east-1"
export DB_MASTER_USERNAME="postgres"
export DJANGO_ALLOWED_HOSTS="api.lightwave-media.ltd,*.amazonaws.com"

# Step 2: Run bootstrap script
./scripts/bootstrap-production.sh

# This will:
# 1. Verify prerequisites
# 2. Build Docker image for ARM64
# 3. Push to ECR
# 4. Deploy Terragrunt stack (PostgreSQL, Redis, Django, Cloudflare DNS)
# 5. Wait for health checks
# 6. Output production URLs
```

### Option 2: Manual Deployment

```bash
# Step 1: Build and push Docker image
cd units/django-fargate-stateful-service/src
docker build --platform linux/arm64 -t lightwave-django:prod .
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL
docker tag lightwave-django:prod $ECR_REPOSITORY_URL:prod
docker push $ECR_REPOSITORY_URL:prod

# Step 2: Deploy stack
cd ../../stacks/django-backend-prod
terragrunt stack plan
terragrunt stack apply

# Step 3: Wait for health checks
curl https://api.lightwave-media.ltd/health/live/
curl https://api.lightwave-media.ltd/health/ready/
```

## ✅ Post-Deployment

### 1. Run Database Migrations

```bash
# Get ECS task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster lightwave-django-prod \
  --query 'taskArns[0]' --output text \
  --profile lightwave-admin-new)

# Run migrations
aws ecs execute-command \
  --cluster lightwave-django-prod \
  --task $TASK_ARN \
  --container django \
  --interactive \
  --command "python manage.py migrate" \
  --profile lightwave-admin-new
```

### 2. Create Django Superuser

```bash
aws ecs execute-command \
  --cluster lightwave-django-prod \
  --task $TASK_ARN \
  --container django \
  --interactive \
  --command "python manage.py createsuperuser" \
  --profile lightwave-admin-new
```

### 3. Test Endpoints

```bash
# Liveness check
curl https://api.lightwave-media.ltd/health/live/
# Expected: {"status": "ok", "service": "django-api"}

# Readiness check
curl https://api.lightwave-media.ltd/health/ready/
# Expected: {"status": "healthy", "checks": {"database": true, "cache": true}}

# JWT token endpoint
curl -X POST https://api.lightwave-media.ltd/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your-password"}'
```

### 4. Access Django Admin

```bash
open https://api.lightwave-media.ltd/admin/
```

## 📊 Monitoring

### CloudWatch Logs

```bash
# Django application logs
aws logs tail /ecs/lightwave-django-prod --follow --profile lightwave-admin-new

# PostgreSQL logs
aws logs tail /aws/rds/instance/lightwave-django-prod/postgresql --follow

# Redis slow log
aws logs tail /aws/elasticache/lightwave-django-prod/slow-log --follow
```

### CloudWatch Metrics Dashboard

Key metrics to monitor:
- **ECS**: CPUUtilization, MemoryUtilization, TargetResponseTime
- **RDS**: DatabaseConnections, CPUUtilization, FreeStorageSpace, ReadLatency
- **Redis**: CacheHits, CacheMisses, CPUUtilization, Evictions
- **ALB**: TargetResponseTime, HTTPCode_Target_2XX_Count, HTTPCode_Target_5XX_Count

### Cloudflare Analytics

Access via Cloudflare Dashboard:
- Requests per second
- Bandwidth usage
- Cache hit ratio
- Security threats blocked
- Response time (p50, p95, p99)

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Django Backend

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Build and push Docker image
        run: |
          cd units/django-fargate-stateful-service/src
          docker build --platform linux/arm64 -t lightwave-django:${{ github.sha }} .
          aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REPOSITORY_URL
          docker tag lightwave-django:${{ github.sha }} $ECR_REPOSITORY_URL:prod
          docker push $ECR_REPOSITORY_URL:prod

      - name: Deploy infrastructure
        env:
          VPC_ID: ${{ secrets.VPC_ID }}
          PRIVATE_SUBNET_IDS: ${{ secrets.PRIVATE_SUBNET_IDS }}
          PUBLIC_SUBNET_IDS: ${{ secrets.PUBLIC_SUBNET_IDS }}
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ZONE_ID: ${{ secrets.CLOUDFLARE_ZONE_ID }}
        run: |
          cd stacks/django-backend-prod
          terragrunt stack apply -auto-approve
```

## 🛠️ Troubleshooting

### Health Checks Failing

**Symptom**: ALB shows unhealthy targets

**Solutions**:
1. Check Django logs: `aws logs tail /ecs/lightwave-django-prod --follow`
2. Verify database connection: Check security group rules allow ECS → RDS on port 5432
3. Verify Redis connection: Check security group rules allow ECS → Redis on port 6379
4. Test health endpoint directly: `curl http://<task-private-ip>:8000/health/live/`

### Database Connection Errors

**Symptom**: "could not connect to server" in logs

**Solutions**:
1. Verify DATABASE_URL environment variable is correct
2. Check RDS security group allows inbound from ECS security group
3. Verify RDS endpoint is correct: `terragrunt output endpoint` from postgresql unit
4. Test connection from ECS task using `psql`

### Cloudflare DNS Not Resolving

**Symptom**: `api.lightwave-media.ltd` not resolving

**Solutions**:
1. Verify CLOUDFLARE_API_TOKEN is valid
2. Check zone_id is correct for lightwave-media.ltd
3. Verify domain nameservers point to Cloudflare
4. Wait for DNS propagation (up to 5 minutes)
5. Check Cloudflare dashboard for DNS record

### Docker Build Fails

**Symptom**: "permission denied" or platform mismatch

**Solutions**:
1. Ensure Docker is running: `docker info`
2. Build for correct platform: `--platform linux/arm64`
3. Check Dockerfile syntax
4. Verify all dependencies in `pyproject.toml`

## 💰 Cost Optimization

1. **Use ARM64 instances** (t4g) - 20% cheaper than x86 (t3)
2. **Enable auto-scaling** - Scale down during low traffic periods
3. **Use Reserved Instances** - Save up to 72% for 1-3 year commitments
4. **Use Savings Plans** - Flexible commitment across services
5. **Monitor unused resources** - Use AWS Cost Explorer

## 🔒 Security Best Practices

1. ✅ **Secrets Manager** for all credentials (never environment variables)
2. ✅ **Private subnets** for database and Redis
3. ✅ **Security groups** with least-privilege rules (no 0.0.0.0/0 for internal services)
4. ✅ **Encryption** at rest (RDS, Redis) and in transit (TLS)
5. ✅ **Cloudflare WAF** enabled for DDoS protection
6. ✅ **Regular updates** via auto minor version upgrades
7. ✅ **Audit logs** via CloudWatch
8. ✅ **MFA** on AWS account and Cloudflare

## 📚 Additional Resources

- [PostgreSQL Module Documentation](modules/postgresql/README.md)
- [Redis Module Documentation](modules/redis/README.md)
- [Cloudflare DNS Module Documentation](modules/cloudflare-dns/README.md)
- [Django Unit Documentation](units/django-fargate-stateful-service/README.md)
- [Production Stack Documentation](stacks/django-backend-prod/README.md)
- [Terratest Guide](test/DJANGO_TESTING.md)

## 🆘 Support

For issues or questions:
1. Check CloudWatch logs first
2. Review AWS Console for resource health
3. Check Cloudflare dashboard for DNS/SSL issues
4. Verify all environment variables are set correctly
5. Review [TROUBLESHOOTING.md](test/TROUBLESHOOTING.md) for common issues

## 📝 Changelog

### 2025-10-28 - Initial Release
- Created PostgreSQL module with Multi-AZ support
- Created Redis module with automatic failover
- Created Cloudflare DNS module for automated DNS management
- Created production stack with full orchestration
- Created bootstrap script for one-command deployment
- Integrated with existing Django 5.0+ application
- Production tested with Terratest suite
