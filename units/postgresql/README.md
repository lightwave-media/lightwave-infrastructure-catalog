# PostgreSQL Unit

This unit provisions a production-ready PostgreSQL database using the `postgresql` module.

## Usage

### Production Configuration

```yaml
# config/postgresql.yaml
name: "lightwave-django-prod"
instance_class: "db.t4g.small"
allocated_storage: 50
master_username: "postgres"
master_password: "{{ .Secrets.DB_PASSWORD }}"  # Load from Secrets Manager

# Production settings
environment: "prod"
multi_az: true
backup_retention_period: 30
deletion_protection: true

tags:
  Application: "Django API"
  Environment: "production"
  CostCenter: "engineering"
```

### Development Configuration

```yaml
# config/postgresql-dev.yaml
name: "lightwave-django-dev"
instance_class: "db.t4g.micro"
allocated_storage: 20
master_username: "postgres"
master_password: "{{ .Secrets.DB_PASSWORD }}"

# Development settings
environment: "dev"
multi_az: false
backup_retention_period: 1
deletion_protection: false
skip_final_snapshot: true  # For faster teardown in dev

tags:
  Application: "Django API"
  Environment: "development"
```

## Inputs

All inputs from the `postgresql` module are supported. See [module documentation](../../modules/postgresql/README.md).

## Outputs

- `endpoint` - PostgreSQL connection endpoint
- `connection_string` - Full DATABASE_URL for Django
- `db_security_group_id` - Security group ID (for allowing access from Django)

## Deployment

```bash
# Deploy production database
cd units/postgresql
terragrunt apply

# Get connection string
terragrunt output connection_string
```

## Post-Deployment

### Allow Django Service Access

```hcl
# In Django ECS service configuration
resource "aws_security_group_rule" "django_to_db" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = dependency.postgresql.outputs.db_security_group_id
  source_security_group_id = aws_security_group.django_service.id
}
```

### Store Connection Details in Secrets Manager

```bash
# After deployment
DB_ENDPOINT=$(terragrunt output -raw endpoint)
DB_NAME=$(terragrunt output -raw db_name)

aws secretsmanager put-secret-value \
  --secret-id /lightwave/prod/django/database-url \
  --secret-string "postgresql://postgres:${DB_PASSWORD}@${DB_ENDPOINT}/${DB_NAME}"
```

## Monitoring

Access CloudWatch logs:
```bash
aws logs tail /aws/rds/instance/lightwave-django-prod/postgresql --follow
```

View Performance Insights in AWS Console:
- RDS → Databases → lightwave-django-prod → Performance Insights

## Example Integration with Django Unit

```hcl
# units/django-fargate-stateful-service/terragrunt.hcl

dependency "postgresql" {
  config_path = "../postgresql"
  mock_outputs = {
    connection_string = "postgresql://user:pass@localhost:5432/db"
    db_security_group_id = "sg-12345"
  }
}

inputs = {
  database_url = dependency.postgresql.outputs.connection_string

  # Allow Django to access database
  additional_security_group_rules = [{
    type                     = "ingress"
    from_port                = 5432
    to_port                  = 5432
    protocol                 = "tcp"
    security_group_id        = dependency.postgresql.outputs.db_security_group_id
    source_security_group_id = local.django_security_group_id
  }]
}
```
