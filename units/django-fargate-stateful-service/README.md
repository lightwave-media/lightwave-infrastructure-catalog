# Django Fargate Stateful Service Unit

Production-ready Django 5.0+ REST Framework application configured for AWS ECS Fargate deployment.

## Features

- **Django 5.0+** with REST Framework 3.15+
- **JWT Authentication** via djangorestframework-simplejwt
- **Celery** task queue with Redis broker
- **PostgreSQL** database support
- **Health Check Endpoints** for ECS/ALB monitoring
- **Multi-stage Docker Build** optimized for ARM64/X86_64
- **Gunicorn** WSGI server with production configuration
- **90% Test Coverage** enforcement via pytest
- **Modern Tooling**: uv package manager, black, ruff, mypy

## Quick Start

### Local Development

```bash
cd src/

# Install dependencies with uv
uv sync

# Activate virtual environment
source .venv/bin/activate

# Set environment variables
export DJANGO_SECRET_KEY="dev-secret-key"
export DATABASE_URL="postgresql://user:pass@localhost:5432/django_db"
export DEBUG=True

# Run migrations
python manage.py migrate

# Create superuser
python manage.py createsuperuser

# Run development server
python manage.py runserver
```

### Docker Build

```bash
cd src/

# Build image
docker build -t django-api:latest .

# Run container
docker run -p 8000:8000 \
  -e DJANGO_SECRET_KEY="your-secret-key" \
  -e DATABASE_URL="postgresql://user:pass@host:5432/db" \
  -e DJANGO_ALLOWED_HOSTS="*" \
  django-api:latest
```

### Test Health Endpoints

```bash
# Liveness probe
curl http://localhost:8000/health/live/

# Readiness probe
curl http://localhost:8000/health/ready/
```

## Project Structure

```
src/
├── config/                     # Django project settings
│   ├── settings/
│   │   ├── base.py            # Shared settings
│   │   ├── dev.py             # Development overrides
│   │   ├── prod.py            # Production settings
│   │   └── test.py            # Test settings
│   ├── urls.py                # URL routing
│   ├── wsgi.py                # WSGI entry point
│   └── asgi.py                # ASGI entry point
├── apps/
│   ├── core/                  # Core API app
│   │   ├── urls.py            # JWT token endpoints
│   │   └── apps.py
│   └── health/                # Health check app
│       ├── views.py           # Liveness/readiness endpoints
│       └── urls.py
├── manage.py                  # Django CLI
├── pyproject.toml             # uv dependencies
├── Dockerfile                 # Multi-stage build
├── gunicorn.conf.py           # Gunicorn configuration
├── wsgi.sh                    # Container entrypoint
└── .dockerignore
```

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `DJANGO_SECRET_KEY` | Django secret key (from Secrets Manager) | `your-secret-key` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host:5432/db` |
| `DJANGO_ALLOWED_HOSTS` | Comma-separated allowed hosts | `api.example.com,*.amazonaws.com` |

### Optional

| Variable | Description | Default |
|----------|-------------|---------|
| `DJANGO_SETTINGS_MODULE` | Settings module to use | `config.settings.prod` |
| `DEBUG` | Enable debug mode | `False` |
| `REDIS_URL` | Redis connection URL | `None` |
| `CELERY_BROKER_URL` | Celery broker URL | Same as `REDIS_URL` |
| `ENVIRONMENT` | Environment name | `production` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `GUNICORN_WORKERS` | Number of Gunicorn workers | `(CPU * 2) + 1` |
| `GUNICORN_LOG_LEVEL` | Gunicorn log level | `info` |

## API Endpoints

### Authentication

```bash
# Obtain JWT token
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "password"}'

# Refresh JWT token
curl -X POST http://localhost:8000/api/token/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh": "your-refresh-token"}'
```

### Health Checks

- **Liveness**: `GET /health/live/` - Returns 200 if app is running
- **Readiness**: `GET /health/ready/` - Returns 200 if database is accessible

## Testing

```bash
# Run tests with coverage
pytest

# Run tests in parallel
pytest -n auto

# Run specific test
pytest test/test_health.py

# Coverage report
pytest --cov-report=html
open htmlcov/index.html
```

## Code Quality

```bash
# Format code
black .

# Lint code
ruff check .

# Type checking
mypy .

# Run all checks
black . && ruff check . && mypy . && pytest
```

## Deployment to ECS

See the Terraform module documentation at `modules/django-fargate-service/README.md` for deployment instructions.

### Infrastructure Dependencies

This unit requires:
1. **ECR Repository** - For Docker image storage
2. **PostgreSQL RDS** - Database
3. **Redis ElastiCache** - Caching and Celery broker (optional)
4. **Secrets Manager** - For Django SECRET_KEY
5. **VPC & Subnets** - Network configuration
6. **Security Groups** - Network access control

## Django Admin

Access the Django admin at `/admin/`:

```bash
# Create superuser
python manage.py createsuperuser

# Access admin
open http://localhost:8000/admin/
```

## Celery (Async Tasks)

```bash
# Start Celery worker
celery -A config worker -l info

# Start Celery beat (scheduler)
celery -A config beat -l info
```

## Database Migrations

```bash
# Create migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate

# Show migrations
python manage.py showmigrations
```

## Troubleshooting

### Database Connection Errors

1. Verify `DATABASE_URL` is correct
2. Check database is accessible from container
3. Verify database user has proper permissions

### Health Check Failures

1. Check Django is listening on port 8000
2. Verify health endpoints return 200:
   ```bash
   curl http://localhost:8000/health/live/
   curl http://localhost:8000/health/ready/
   ```
3. Check database connectivity

### Container Startup Issues

1. Review container logs for errors
2. Verify all required environment variables are set
3. Check database migrations completed successfully
4. Verify static files were collected

## Dependencies

- Python 3.12+
- Django 5.0+
- PostgreSQL 15+ (via DATABASE_URL)
- Redis 7+ (optional, for caching/Celery)

## License

MPL-2.0
