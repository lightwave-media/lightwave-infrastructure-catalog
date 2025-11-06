# Django Fargate Service - Terratest Guide

Comprehensive testing guide for the Django Fargate service using Terratest.

## Overview

The Django infrastructure includes multiple levels of testing:

1. **Module Tests** - Validate Terraform module configuration
2. **Unit Tests** - Test complete service deployment
3. **Integration Tests** - Validate Django API functionality
4. **Performance Tests** - Measure startup time and response latency

## Test Files

| File | Purpose | Runtime |
|------|---------|---------|
| `terragrunt/units/django_fargate_service_test.go` | Unit deployment test | ~5 min |
| `django_integration_test.go` | Full Django API integration test | ~8 min |

## Prerequisites

### Required Tools

```bash
# 1. Install Go
brew install go

# 2. Install Terragrunt
brew install terragrunt

# 3. Install Terraform/OpenTofu
brew install opentofu

# 4. Configure AWS credentials
aws configure --profile lightwave-admin-new
```

### Required AWS Resources

Before running tests, ensure you have:

- **ECR Repository** for Docker images
- **Secrets Manager** secret for Django SECRET_KEY
- **VPC and Subnets** (default VPC works)
- **IAM Permissions** to create:
  - ECS clusters, services, tasks
  - Application Load Balancers
  - Security Groups
  - CloudWatch Log Groups

### Environment Variables

```bash
export AWS_PROFILE=lightwave-admin-new
export AWS_REGION=us-east-1
export TG_BUCKET_PREFIX=lightwave-
```

## Running Tests

### Run All Tests

```bash
cd test/
go test -v -timeout 60m ./...
```

### Run Specific Test Suite

```bash
# Django unit test only
go test -v -timeout 30m ./terragrunt/units -run TestUnitDjangoFargateService

# Django integration tests only
go test -v -timeout 30m -run TestDjangoIntegration

# Module validation only
go test -v -timeout 10m ./terragrunt/units -run TestDjangoModuleMinimal
```

### Run with Verbose Output

```bash
go test -v -timeout 60m ./... 2>&1 | tee test-output.log
```

## Test Scenarios

### 1. Module Validation Test (`TestDjangoModuleMinimal`)

**Duration**: ~2 minutes
**Cost**: $0 (no resources created)

**What it does**:
- Validates Terraform syntax
- Checks required variables
- Verifies outputs are defined
- Runs `terraform plan`

**Run**:
```bash
go test -v ./terragrunt/units -run TestDjangoModuleMinimal
```

**Expected output**:
```
=== RUN   TestDjangoModuleMinimal
=== RUN   TestDjangoModuleMinimal/Outputs
    django_fargate_service_test.go:95: ✅ Output 'url' is defined
    django_fargate_service_test.go:96: ✅ Output 'alb_dns_name' is defined
    django_fargate_service_test.go:97: ✅ Output 'service_security_group_id' is defined
--- PASS: TestDjangoModuleMinimal (2.34s)
PASS
```

### 2. Unit Deployment Test (`TestUnitDjangoFargateService`)

**Duration**: ~5 minutes
**Cost**: ~$0.50 (ECS Fargate, ALB)

**What it does**:
- Deploys complete Django service to ECS
- Waits for service to become healthy
- Tests `/health/live/` endpoint
- Tests `/health/ready/` endpoint
- Validates database connectivity
- Destroys resources after test

**Run**:
```bash
go test -v -timeout 30m ./terragrunt/units -run TestUnitDjangoFargateService
```

**Expected output**:
```
=== RUN   TestUnitDjangoFargateService
=== RUN   TestUnitDjangoFargateService/Liveness
    django_fargate_service_test.go:56: ✅ Liveness check passed: {"status":"ok","service":"django-api"}
=== RUN   TestUnitDjangoFargateService/Readiness
    django_fargate_service_test.go:91: ✅ Readiness check passed: database=true, cache=true
    django_fargate_service_test.go:48: Django service started in 4m32s
--- PASS: TestUnitDjangoFargateService (5m12s)
PASS
```

### 3. Integration Tests (`TestDjangoIntegrationFull`)

**Duration**: ~8 minutes
**Cost**: ~$0.70 (ECS Fargate, ALB)

**What it does**:
- Deploys complete infrastructure
- Tests health endpoints
- Tests JWT token endpoints
- Tests API throttling configuration
- Tests CORS headers
- Validates Django settings
- Measures response times

**Run**:
```bash
go test -v -timeout 30m -run TestDjangoIntegrationFull
```

**Expected output**:
```
=== RUN   TestDjangoIntegrationFull
=== RUN   TestDjangoIntegrationFull/WaitForHealthy
    django_integration_test.go:42: ✅ Service is healthy after 24 attempts
=== RUN   TestDjangoIntegrationFull/HealthEndpoints
=== RUN   TestDjangoIntegrationFull/HealthEndpoints/Liveness
=== RUN   TestDjangoIntegrationFull/HealthEndpoints/Readiness
=== RUN   TestDjangoIntegrationFull/JWTAuthentication
=== RUN   TestDjangoIntegrationFull/JWTAuthentication/InvalidCredentials
=== RUN   TestDjangoIntegrationFull/JWTAuthentication/TokenEndpointAccessible
=== RUN   TestDjangoIntegrationFull/APIThrottling
    django_integration_test.go:153: API throttling test: received 10 responses
=== RUN   TestDjangoIntegrationFull/CORSHeaders
    django_integration_test.go:163: CORS test: OPTIONS request returned 200
--- PASS: TestDjangoIntegrationFull (8m45s)
PASS
```

### 4. Performance Test (`TestDjangoContainerStartupTime`)

**Duration**: ~4 minutes
**Cost**: ~$0.30 (ECS Fargate)

**What it does**:
- Measures container cold start time
- Validates startup is < 3 minutes
- Logs performance metrics

**Run**:
```bash
go test -v -timeout 30m -run TestDjangoContainerStartupTime
```

**Expected output**:
```
=== RUN   TestDjangoContainerStartupTime
    django_integration_test.go:179: ⏱️  Container startup time: 2m34s
    django_integration_test.go:186: Performance Metrics:
    django_integration_test.go:187:   - Total startup time: 2m34s
    django_integration_test.go:188:   - Target: < 3 minutes
    django_integration_test.go:189:   - Status: ✅ Good
--- PASS: TestDjangoContainerStartupTime (4m01s)
PASS
```

## Test Assertions

### Health Checks

**Liveness Endpoint** (`/health/live/`):
```json
{
  "status": "ok",
  "service": "django-api"
}
```

**Assertions**:
- HTTP 200 status code
- JSON response with `status: "ok"`
- Response time < 500ms

**Readiness Endpoint** (`/health/ready/`):
```json
{
  "status": "healthy",
  "checks": {
    "database": true,
    "cache": true
  }
}
```

**Assertions**:
- HTTP 200 status code
- JSON response with `status: "healthy"`
- Database check passes
- Cache check passes (if Redis configured)

### JWT Authentication

**Token Endpoint** (`/api/token/`):

**Assertions**:
- Endpoint is accessible (POST)
- Returns 401 for invalid credentials
- Returns 405 for GET requests (POST-only)

### Performance

**Startup Time**:
- **Target**: < 3 minutes
- **Good**: < 2 minutes
- **Excellent**: < 1.5 minutes

**Includes**:
- Terraform apply time
- Docker image pull
- Django migrations
- Static file collection
- Gunicorn startup

## Troubleshooting

### Test Failures

#### "Service did not become healthy within timeout"

**Causes**:
1. Database connection failure
2. Django migrations failed
3. Container image not found in ECR
4. Insufficient ECS task resources

**Debug**:
```bash
# Check ECS task logs
aws ecs list-tasks --cluster test-django-minimal
aws ecs describe-tasks --cluster test-django-minimal --tasks <task-arn>

# Check CloudWatch logs
aws logs tail /ecs/test-django-minimal --follow
```

#### "Container startup time exceeded 3 minutes"

**Causes**:
1. Large Docker image
2. Slow database migrations
3. Network latency
4. Cold start delays

**Solutions**:
- Use ARM64 architecture (faster)
- Optimize Docker image size
- Pre-run migrations in CI/CD
- Increase ECS task resources

### AWS Costs

**Approximate costs per test run**:

| Resource | Duration | Cost |
|----------|----------|------|
| ECS Fargate (0.25 vCPU, 512 MB) | 5 min | $0.004 |
| Application Load Balancer | 5 min | $0.015 |
| NAT Gateway (data transfer) | 5 min | $0.005 |
| CloudWatch Logs | 5 min | $0.001 |
| **Total per test** | - | **~$0.025** |

**Full test suite** (~60 min): **~$0.30**

### Cleanup Failed Tests

If tests fail and resources aren't destroyed:

```bash
# List ECS clusters
aws ecs list-clusters

# Delete cluster
aws ecs delete-cluster --cluster test-django-minimal

# List ALBs
aws elbv2 describe-load-balancers

# Delete ALB
aws elbv2 delete-load-balancer --load-balancer-arn <arn>

# Or use cloud-nuke
cloud-nuke aws --resource-type ecs --resource-type elb
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Django Infrastructure Tests

on:
  pull_request:
    paths:
      - 'modules/django-fargate-service/**'
      - 'units/django-fargate-stateful-service/**'
      - 'test/**'

jobs:
  terratest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.24'

      - name: Install Terragrunt
        run: |
          wget https://github.com/gruntwork-io/terragrunt/releases/download/v0.82.3/terragrunt_linux_amd64
          chmod +x terragrunt_linux_amd64
          sudo mv terragrunt_linux_amd64 /usr/local/bin/terragrunt

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Run Module Tests
        run: |
          cd test/
          go test -v -timeout 30m ./terragrunt/units -run TestDjangoModuleMinimal

      - name: Run Integration Tests
        if: github.event_name == 'push'
        run: |
          cd test/
          go test -v -timeout 60m ./terragrunt/units -run TestUnitDjangoFargateService
```

## Best Practices

### Test Execution

1. **Run module tests first** (fast, cheap)
2. **Run unit tests** (medium, validates deployment)
3. **Run integration tests** (slow, expensive, validates full stack)
4. **Run performance tests** (measure baselines)

### Cost Optimization

1. Use `t.Parallel()` to run tests concurrently
2. Skip expensive tests in PR checks
3. Run full suite only on main branch
4. Clean up resources in `defer` statements
5. Use small ECS task sizes for tests

### Debugging

1. Always check CloudWatch logs first
2. Use `t.Logf()` for debugging output
3. Set longer timeouts for slow tests
4. Keep `defer destroy` to avoid orphaned resources

## References

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Django Testing Best Practices](https://docs.djangoproject.com/en/5.0/topics/testing/)
- [AWS ECS Testing Guide](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/testing.html)
- [Gruntwork Infrastructure Testing](https://gruntwork.io/guides/testing/)
