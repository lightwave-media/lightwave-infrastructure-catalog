# PostgreSQL Module

This module provisions a production-ready Amazon RDS PostgreSQL database with Django-optimized configuration.

## Features

- **High Availability**: Multi-AZ deployment with automatic failover
- **Security**: Encryption at rest and in transit, VPC security groups
- **Backups**: Automated daily backups with configurable retention
- **Performance**: Performance Insights enabled, SSD storage (gp3)
- **Monitoring**: CloudWatch logs for PostgreSQL and upgrades
- **Auto-scaling**: Storage auto-scaling up to configurable limit
- **Django-optimized**: Parameter group tuned for Django applications

## Usage

```hcl
module "postgresql" {
  source = "../../modules/postgresql"

  name              = "my-django-db"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20

  master_username = "postgres"
  master_password = var.db_password  # Load from Secrets Manager

  # Production settings
  environment            = "prod"
  multi_az               = true
  backup_retention_period = 7
  deletion_protection    = true

  tags = {
    Application = "Django API"
    Owner       = "Platform Team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | The name of the DB | string | - | yes |
| instance_class | The instance class (e.g. db.t4g.micro) | string | - | yes |
| allocated_storage | Storage in GB | number | - | yes |
| master_username | Master username | string | - | yes |
| master_password | Master password | string | - | yes |
| engine_version | PostgreSQL version | string | 15.10 | no |
| multi_az | Enable Multi-AZ | bool | true | no |
| backup_retention_period | Backup retention in days | number | 7 | no |
| storage_encrypted | Enable encryption | bool | true | no |
| deletion_protection | Enable deletion protection | bool | true | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| endpoint | Connection endpoint (hostname:port) |
| address | Database hostname |
| port | Database port |
| db_name | Database name |
| arn | RDS instance ARN |
| db_security_group_id | Security group ID |
| connection_string | Full DATABASE_URL for Django |

## PostgreSQL Configuration

This module creates a parameter group with Django-optimized settings:

- `shared_buffers`: 256MB (25% of t4g.micro RAM)
- `max_connections`: 100 connections
- `work_mem`: 4MB per operation
- `maintenance_work_mem`: 64MB for VACUUM/INDEX
- `effective_cache_size`: 1GB hint for query planner
- `random_page_cost`: 1.1 (optimized for SSD)
- `log_min_duration_statement`: 1000ms (log slow queries)

### Instance Sizing Recommendations

| Environment | Instance Class | vCPU | RAM | Storage | Cost/month |
|-------------|---------------|------|-----|---------|------------|
| Dev/Test | db.t4g.micro | 2 | 1 GB | 20 GB | $14 |
| Staging | db.t4g.small | 2 | 2 GB | 50 GB | $28 |
| Production | db.t4g.medium | 2 | 4 GB | 100 GB | $56 |
| High-traffic | db.r6g.large | 2 | 16 GB | 250 GB | $150 |

## Security

- Encryption at rest enabled by default (AWS managed KMS key)
- Encryption in transit via SSL/TLS
- Database accessible only via security group rules
- Master password should be stored in AWS Secrets Manager
- CloudWatch logs exported for audit

## Connecting from Django

Use the `connection_string` output:

```python
# config/settings/prod.py
import os
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ['DB_NAME'],
        'USER': os.environ['DB_USER'],
        'PASSWORD': os.environ['DB_PASSWORD'],
        'HOST': os.environ['DB_HOST'],
        'PORT': os.environ['DB_PORT'],
        'OPTIONS': {
            'sslmode': 'require',
        },
    }
}

# Or use DATABASE_URL:
DATABASES = {
    'default': dj_database_url.config(default=os.environ.get('DATABASE_URL'))
}
```

## Backup and Restore

Automated backups occur during the `backup_window` (default: 03:00-04:00 UTC).

Manual snapshot:
```bash
aws rds create-db-snapshot \
  --db-instance-identifier my-django-db \
  --db-snapshot-identifier my-django-db-manual-2025-01-01
```

Restore from snapshot:
```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier my-django-db-restored \
  --db-snapshot-identifier my-django-db-manual-2025-01-01
```

## Monitoring

CloudWatch metrics available:
- `CPUUtilization`
- `DatabaseConnections`
- `FreeStorageSpace`
- `ReadLatency` / `WriteLatency`
- `ReadIOPS` / `WriteIOPS`

Performance Insights available in RDS console for query analysis.

## Upgrading PostgreSQL Version

To upgrade major versions:

1. Update `engine_version` variable
2. Update `parameter_group_family` (e.g. `postgres15` → `postgres16`)
3. Run `terraform plan` to verify
4. Apply during maintenance window

```hcl
module "postgresql" {
  # ...
  engine_version          = "16.6"
  parameter_group_family  = "postgres16"
}
```

## Example: Production Configuration

```hcl
module "postgresql_prod" {
  source = "../../modules/postgresql"

  name              = "lightwave-django-prod"
  instance_class    = "db.t4g.small"
  allocated_storage = 50
  max_allocated_storage = 250

  master_username = "postgres"
  master_password = data.aws_secretsmanager_secret_version.db_password.secret_string

  environment            = "prod"
  multi_az               = true
  backup_retention_period = 30
  deletion_protection    = true
  storage_encrypted      = true

  performance_insights_enabled = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  # Custom parameter tuning for production
  shared_buffers       = "65536"  # 512MB
  max_connections      = "200"
  work_mem             = "8192"   # 8MB
  maintenance_work_mem = "131072" # 128MB
  effective_cache_size = "262144" # 2GB

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
cd examples/tofu/postgresql
tofu init
tofu plan
```

Run Terratest:
```bash
cd test
go test -v -timeout 30m -run TestPostgreSQLModule
```
