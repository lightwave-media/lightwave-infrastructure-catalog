# Infrastructure Testing Guide

Comprehensive guide for testing infrastructure modules with Terratest in the LightWave Media infrastructure catalog.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Test Types](#test-types)
- [Running Tests](#running-tests)
- [Writing Tests](#writing-tests)
- [CI/CD Integration](#cicd-integration)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

---

## Overview

This testing framework uses [Terratest](https://terratest.gruntwork.io/) to provide automated testing for infrastructure modules. Tests deploy real infrastructure to AWS, validate functionality, and clean up resources.

### What Gets Tested

- **Module Configuration**: Terraform/OpenTofu syntax validation
- **Resource Deployment**: Successful infrastructure creation
- **Functional Validation**: Services work as expected
- **Resource Cleanup**: Proper destruction of resources
- **Integration**: Modules work together correctly

### Test Coverage

| Module | Tests | Coverage | Status |
|--------|-------|----------|--------|
| ECS Fargate Service | 5 tests | Full | ✅ Complete |
| PostgreSQL RDS | 6 tests | Full | ✅ Complete |
| Redis ElastiCache | 6 tests | Full | ✅ Complete |
| Django Fargate Service | 3 tests | Integration | ✅ Complete |
| S3 Bucket | 1 test | Basic | ⚠️ Minimal |
| DynamoDB Table | 1 test | Basic | ⚠️ Minimal |

---

## Quick Start

### Prerequisites

1. **Required Tools**:
   ```bash
   # Install Go (1.24+)
   brew install go

   # Install OpenTofu
   brew install opentofu

   # Install Terragrunt
   brew install terragrunt
   ```

2. **AWS Credentials**:
   ```bash
   export AWS_PROFILE=lightwave-admin-new
   # Verify credentials
   aws sts get-caller-identity
   ```

3. **Install Dependencies**:
   ```bash
   cd test
   make setup
   ```

### Run Your First Test

```bash
# Run quick validation (no deployment, free)
make test-modules-minimal

# Run a single module test (deploys infrastructure, costs money)
make test-ecs-module
```

---

## Test Types

### 1. Minimal Tests (Fast, Free)

**Purpose**: Validate Terraform configuration without deploying infrastructure.

**What they test**:
- Terraform syntax is valid
- Required variables are defined
- Module can generate a plan

**Example**:
```go
func TestECSFargateServiceModuleMinimal(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../../examples/tofu/ecs-fargate-service",
        Vars: map[string]interface{}{
            "name": "test-ecs",
        },
    }

    terraform.Init(t, opts)
    terraform.Validate(t, opts)
    terraform.Plan(t, opts)
}
```

**Run**: `make test-modules-minimal`

**Duration**: 1-2 minutes
**Cost**: $0

---

### 2. Module Tests (Deploy, Validate, Destroy)

**Purpose**: Deploy infrastructure and validate it works correctly.

**What they test**:
- Resources are created successfully
- Outputs are correct
- Services are accessible
- Resources can be destroyed cleanly

**Example**:
```go
func TestECSFargateServiceModule(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../../examples/tofu/ecs-fargate-service",
        Vars: map[string]interface{}{
            "name": fmt.Sprintf("ecs-test-%s", random.UniqueId()),
        },
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Validate outputs
    url := terraform.Output(t, opts, "url")
    http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello World!", 30, 5*time.Second)
}
```

**Run**: `make test-ecs-module`

**Duration**: 5-10 minutes
**Cost**: ~$0.50-$1.00

---

### 3. Integration Tests

**Purpose**: Test multiple modules working together (e.g., ECS + RDS + Redis).

**What they test**:
- Modules integrate correctly
- Data flows between services
- End-to-end functionality

**Example**:
```go
func TestDjangoIntegrationFull(t *testing.T) {
    // Deploy complete stack: ECS + RDS + Redis + ALB
    // Validate Django app can:
    // - Connect to database
    // - Use Redis cache
    // - Serve HTTP requests
}
```

**Run**: `make test-django-integration`

**Duration**: 15-20 minutes
**Cost**: ~$2-3

---

### 4. Performance Tests

**Purpose**: Measure startup times, response times, resource utilization.

**Example**:
```go
func TestDjangoContainerStartupTime(t *testing.T) {
    startTime := time.Now()

    // Deploy and wait for healthy
    // ...

    duration := time.Since(startTime)
    assert.Less(t, duration.Seconds(), 180.0, "Should start within 3 minutes")
}
```

**Run**: `make test-django-performance`

**Duration**: 5-10 minutes
**Cost**: ~$0.50

---

## Running Tests

### Local Development

#### Run all minimal tests (recommended for PR checks)
```bash
cd test
make test-modules-minimal
```

#### Run specific module test
```bash
make test-ecs-module          # ECS Fargate (~5 min, ~$1)
make test-postgresql-module   # PostgreSQL RDS (~15 min, ~$2)
make test-redis-module        # Redis ElastiCache (~10 min, ~$1)
```

#### Run all core module tests
```bash
make test-core-modules        # All 3 above (parallel, ~20 min, ~$4)
```

#### Run Django-specific tests
```bash
make test-django-module       # Validate only (free)
make test-django-unit         # Deploy and test (~5 min, ~$0.50)
make test-django-integration  # Full integration (~8 min, ~$0.70)
```

### Test-Specific Commands

```bash
# Run a specific test by name
go test -v -timeout 30m ./modules -run TestECSFargateServiceModule

# Run tests in a specific package
go test -v -timeout 30m ./modules

# Run tests with verbose output
go test -v -timeout 30m ./...

# Run tests in parallel
go test -v -timeout 30m -parallel 3 ./modules
```

### CI/CD Commands (no prompts)

```bash
make ci-test-modules-minimal      # Module validation
make ci-test-ecs-module           # ECS tests
make ci-test-postgresql-module    # PostgreSQL tests
make ci-test-redis-module         # Redis tests
make ci-test-all                  # All tests
```

---

## Writing Tests

### Test Structure

```go
package modules_test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/require"
)

// Test naming: Test<Module><Type>
func TestMyModuleMinimal(t *testing.T) {
    t.Parallel() // Enable parallel execution

    // 1. Setup
    opts := &terraform.Options{
        TerraformDir: "../../examples/tofu/my-module",
        Vars: map[string]interface{}{
            "name": "test-name",
        },
    }

    // 2. Cleanup (deferred)
    defer terraform.Destroy(t, opts)

    // 3. Deploy
    terraform.InitAndApply(t, opts)

    // 4. Validate
    output := terraform.Output(t, opts, "my_output")
    require.NotEmpty(t, output)

    // 5. Test functionality
    // ... custom validation logic ...
}
```

### Using Test Helpers

The `helpers` package provides reusable functions:

```go
import "github.com/lightwave-media/lightwave-infrastructure-catalog/test/helpers"

// AWS session management
sess := helpers.GetAWSSession(t, helpers.AWSSessionConfig{
    Region: "us-east-1",
})

// Wait for resources
helpers.WaitForRDSInstanceAvailable(t, sess, "my-db", 10*time.Minute)
helpers.WaitForECSServiceStable(t, sess, clusterARN, serviceName, 5*time.Minute)

// Retry operations
helpers.RetryUntilSuccess(t, helpers.DefaultRetryConfig(), func() (bool, error) {
    // Your validation logic
    return true, nil
})

// Terraform helpers
helpers.ValidateModuleWithoutDeploy(t, opts)
helpers.ValidateRequiredOutputs(t, opts, []string{"url", "arn", "sg_id"})
```

### Testing Patterns

#### Pattern 1: Outputs Validation
```go
func testModuleOutputs(t *testing.T, opts *terraform.Options) {
    // Verify output exists
    endpoint := terraform.Output(t, opts, "endpoint")
    require.NotEmpty(t, endpoint)

    // Verify output format
    require.Contains(t, endpoint, ".amazonaws.com")

    // Verify output matches regex
    arn := terraform.Output(t, opts, "arn")
    require.Regexp(t, "^arn:aws:rds:", arn)
}
```

#### Pattern 2: Service Health Check
```go
func testServiceHealth(t *testing.T, opts *terraform.Options) {
    url := terraform.Output(t, opts, "url")

    http_helper.HttpGetWithRetryWithCustomValidation(
        t,
        url,
        nil,
        30,             // maxRetries
        10*time.Second, // retryInterval
        func(status int, body string) bool {
            return status == 200 && strings.Contains(body, "healthy")
        },
    )
}
```

#### Pattern 3: Database Connectivity
```go
func testDatabaseConnectivity(t *testing.T, opts *terraform.Options) {
    address := terraform.Output(t, opts, "address")
    port := terraform.Output(t, opts, "port")

    connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s",
        address, port, username, password, dbName)

    db, err := sql.Open("postgres", connStr)
    require.NoError(t, err)
    defer db.Close()

    err = db.Ping()
    require.NoError(t, err)
}
```

#### Pattern 4: Subtests
```go
func TestMyModule(t *testing.T) {
    t.Parallel()

    // Deploy once
    opts := setupTerraform(t)
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Run multiple validations
    t.Run("Outputs", func(t *testing.T) {
        testOutputs(t, opts)
    })

    t.Run("Health", func(t *testing.T) {
        testHealth(t, opts)
    })

    t.Run("Connectivity", func(t *testing.T) {
        testConnectivity(t, opts)
    })
}
```

### Test Checklist

When writing a new test, ensure:

- [ ] Test name follows `Test<Module><Type>` convention
- [ ] `t.Parallel()` is called for parallel execution
- [ ] `defer terraform.Destroy()` ensures cleanup
- [ ] Unique names generated with `random.UniqueId()`
- [ ] Timeouts are appropriate (`-timeout 30m`)
- [ ] Outputs are validated
- [ ] Functional validation is performed
- [ ] Error messages are descriptive
- [ ] Test is documented in TESTING_GUIDE.md

---

## CI/CD Integration

### GitHub Actions Workflow

The infrastructure testing workflow runs automatically on:
- Pull requests to `main` or `dev` branches
- Pushes to `main` branch
- Manual trigger via workflow_dispatch

#### Workflow Jobs

1. **Pre-flight Checks** (always runs)
   - Pre-commit hooks
   - Go fmt/vet
   - Duration: 2-3 minutes

2. **Validate Modules** (always runs)
   - Module syntax validation
   - No deployment
   - Duration: 2-3 minutes
   - Cost: $0

3. **Module Tests** (conditional)
   - ECS, PostgreSQL, Redis tests
   - Runs on: push to main, PR with `test:deploy` label
   - Duration: 20-30 minutes (parallel)
   - Cost: ~$4

### Triggering Tests in CI

#### For all PRs (automatic)
```bash
# Opens PR
git push origin feature/my-feature

# CI automatically runs:
# - Pre-flight checks
# - Module validation (no deploy)
```

#### For deployment tests
```bash
# Add label to PR
gh pr edit <PR_NUMBER> --add-label "test:deploy"

# CI runs:
# - All minimal tests
# - All module deployment tests
```

#### Manual trigger
```bash
# From GitHub UI: Actions → Infrastructure Testing → Run workflow
# Or via CLI:
gh workflow run infrastructure-tests.yml -f test_suite=core-modules
```

### Cost Management

The CI/CD pipeline is designed to minimize AWS costs:

| Stage | Duration | Cost | When |
|-------|----------|------|------|
| Pre-flight | 2-3 min | $0 | Every PR |
| Validate | 2-3 min | $0 | Every PR |
| Module Tests | 20-30 min | ~$4 | On label or main push |

**Cost control strategies**:
1. Minimal tests run on every PR (free)
2. Deployment tests require label or main push
3. Tests run in parallel to minimize duration
4. Resources cleaned up immediately after tests
5. Small instance sizes used for testing

---

## Best Practices

### Test Design

1. **Keep tests isolated**: Each test should deploy its own infrastructure
2. **Use unique names**: Prevent conflicts with `random.UniqueId()`
3. **Enable parallelization**: Use `t.Parallel()` for faster execution
4. **Test cleanup**: Always `defer terraform.Destroy()`
5. **Be explicit**: Assert specific values, not just "not empty"

### Performance

1. **Appropriate timeouts**: Set realistic timeouts per test
   - Minimal tests: 10 minutes
   - ECS tests: 30 minutes
   - RDS tests: 45 minutes

2. **Retry configuration**: Use appropriate retry intervals
   - Fast operations: 2 seconds
   - Medium (ECS): 10 seconds
   - Slow (RDS): 10 seconds

3. **Parallel execution**: Run independent tests in parallel
   ```bash
   go test -v -timeout 60m -parallel 3 ./modules
   ```

### Cost Optimization

1. **Use smallest instances**: `db.t3.micro`, `cache.t3.micro`, etc.
2. **Single AZ**: No multi-AZ for tests
3. **Minimal storage**: Use minimum allocations
4. **Disable features**: Turn off unnecessary features (e.g., backups)
5. **Short retention**: Use minimal backup retention

Example:
```go
Vars: map[string]interface{}{
    "instance_class":     "db.t3.micro",  // Smallest RDS instance
    "allocated_storage":  20,             // Minimum storage
    "multi_az":          false,           // Single AZ
    "backup_retention":   1,              // Minimum retention
}
```

### Error Handling

1. **Descriptive assertions**: Include context in error messages
   ```go
   require.NotEmpty(t, url, "ALB URL should be returned in outputs")
   ```

2. **Retry with logging**: Log progress during retries
   ```go
   t.Logf("Retry %d/%d: Waiting for service...", i+1, maxRetries)
   ```

3. **Cleanup on failure**: Use `defer` to ensure cleanup even on failure

### Security

1. **Never hardcode credentials**: Use environment variables or AWS Secrets Manager
2. **Use IAM roles**: Prefer IAM roles over access keys
3. **Rotate test credentials**: Regularly rotate CI/CD credentials
4. **Limit permissions**: Use least-privilege IAM policies

---

## Troubleshooting

### Common Issues

#### Issue: Test timeout
```
Error: test timed out after 30m0s
```

**Solution**:
- Increase timeout: `go test -timeout 45m`
- Check AWS service limits
- Verify network connectivity

#### Issue: Resource already exists
```
Error: resource "aws_db_instance" already exists
```

**Solution**:
- Use unique names with `random.UniqueId()`
- Clean up previous test resources
- Check for leaked resources

#### Issue: AWS credentials not found
```
Error: NoCredentialProviders: no valid providers in chain
```

**Solution**:
```bash
export AWS_PROFILE=lightwave-admin-new
aws sts get-caller-identity
```

#### Issue: Module not found
```
Error: Module not found: terraform-aws-modules/vpc/aws
```

**Solution**:
```bash
cd test
terraform init
```

#### Issue: Connection refused
```
Error: dial tcp: connection refused
```

**Solution**:
- Wait longer for service to be ready
- Check security group rules
- Verify service is running

### Debugging Tests

#### Enable verbose logging
```bash
TF_LOG=DEBUG go test -v -timeout 30m ./modules -run TestMyModule
```

#### Run single test
```bash
go test -v -timeout 30m ./modules -run TestECSFargateServiceModule
```

#### Skip cleanup for debugging
```go
// Temporarily comment out defer for debugging
// defer terraform.Destroy(t, opts)
terraform.InitAndApply(t, opts)
// Inspect resources in AWS Console
```

#### Print all outputs
```go
helpers.PrintTerraformOutputs(t, opts)
```

### Getting Help

1. **Check test logs**: Look for specific error messages
2. **Check AWS Console**: Verify resource state
3. **Review Terratest docs**: https://terratest.gruntwork.io/
4. **Check module README**: Module-specific requirements
5. **Ask team**: Post in #infrastructure Slack channel

---

## Test Coverage Report

### Current Coverage

| Category | Modules | Tests | Coverage |
|----------|---------|-------|----------|
| Compute | 3 | 8 tests | 🟢 Good |
| Database | 2 | 7 tests | 🟢 Good |
| Cache | 1 | 6 tests | 🟢 Good |
| Storage | 1 | 1 test | 🟡 Basic |
| Networking | 0 | 0 tests | 🔴 None |

### Roadmap

Future test additions:

- [ ] VPC module comprehensive tests
- [ ] Security group module tests
- [ ] S3 bucket advanced tests (versioning, lifecycle)
- [ ] DynamoDB table tests (scaling, streams)
- [ ] Lambda service tests
- [ ] CloudFront distribution tests
- [ ] Route53 DNS tests
- [ ] Secrets Manager integration tests

---

## Additional Resources

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Terratest Examples](https://github.com/gruntwork-io/terratest/tree/master/examples)
- [Gruntwork Testing Best Practices](https://gruntwork.io/guides/testing/how-to-test-infrastructure-code/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

**Last Updated**: 2025-10-29
**Maintained By**: Platform Team
**Version**: 1.0.0
