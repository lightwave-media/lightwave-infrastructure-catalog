# Infrastructure Test Patterns

Quick reference for common Terratest patterns used in LightWave Media infrastructure testing.

## Table of Contents

- [Basic Test Structure](#basic-test-structure)
- [Module Testing Patterns](#module-testing-patterns)
- [AWS Resource Validation](#aws-resource-validation)
- [Database Testing](#database-testing)
- [Cache Testing](#cache-testing)
- [Service Health Checks](#service-health-checks)
- [Helper Functions](#helper-functions)

---

## Basic Test Structure

### Minimal Test (No Deployment)

```go
func TestModuleNameMinimal(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir:    "../../examples/tofu/module-name",
        TerraformBinary: "tofu",
        Vars: map[string]interface{}{
            "name": "test-name",
        },
    }

    terraform.Init(t, opts)
    terraform.Validate(t, opts)
    terraform.InitAndPlan(t, opts)
}
```

### Full Test (With Deployment)

```go
func TestModuleName(t *testing.T) {
    t.Parallel()

    uniqueID := random.UniqueId()
    opts := &terraform.Options{
        TerraformDir:    "../../examples/tofu/module-name",
        TerraformBinary: "tofu",
        Vars: map[string]interface{}{
            "name": fmt.Sprintf("test-%s", uniqueID),
        },
        EnvVars: map[string]string{
            "AWS_DEFAULT_REGION": "us-east-1",
        },
    }

    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Validation tests
    t.Run("Outputs", func(t *testing.T) {
        testOutputs(t, opts)
    })

    t.Run("Functionality", func(t *testing.T) {
        testFunctionality(t, opts)
    })
}
```

---

## Module Testing Patterns

### Output Validation

```go
func testOutputs(t *testing.T, opts *terraform.Options) {
    // Check output exists and not empty
    output := terraform.Output(t, opts, "output_name")
    require.NotEmpty(t, output)

    // Verify output format with regex
    require.Regexp(t, "^arn:aws:service:", output)

    // Check output contains expected string
    require.Contains(t, output, ".amazonaws.com")

    // Verify specific value
    assert.Equal(t, "expected-value", output)
}
```

### Multiple Outputs

```go
func testAllOutputs(t *testing.T, opts *terraform.Options) {
    required := []string{"url", "arn", "security_group_id"}

    for _, name := range required {
        output := terraform.Output(t, opts, name)
        require.NotEmpty(t, output, "Output %s should not be empty", name)
        t.Logf("✅ Output %s: %s", name, output)
    }
}
```

---

## AWS Resource Validation

### RDS Instance

```go
func validateRDSInstance(t *testing.T, region, dbIdentifier string) {
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(region),
    })
    require.NoError(t, err)

    rdsClient := rds.New(sess)
    input := &rds.DescribeDBInstancesInput{
        DBInstanceIdentifier: aws.String(dbIdentifier),
    }

    result, err := rdsClient.DescribeDBInstances(input)
    require.NoError(t, err)
    require.NotEmpty(t, result.DBInstances)

    instance := result.DBInstances[0]
    assert.Equal(t, "available", *instance.DBInstanceStatus)
    assert.Equal(t, "postgres", *instance.Engine)
}
```

### ElastiCache Cluster

```go
func validateElastiCache(t *testing.T, region, replicationGroupID string) {
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(region),
    })
    require.NoError(t, err)

    ecClient := elasticache.New(sess)
    input := &elasticache.DescribeReplicationGroupsInput{
        ReplicationGroupId: aws.String(replicationGroupID),
    }

    result, err := ecClient.DescribeReplicationGroups(input)
    require.NoError(t, err)
    require.NotEmpty(t, result.ReplicationGroups)

    cluster := result.ReplicationGroups[0]
    assert.Equal(t, "available", *cluster.Status)
}
```

### ECS Service

```go
func validateECSService(t *testing.T, region, clusterARN, serviceName string) {
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(region),
    })
    require.NoError(t, err)

    ecsClient := ecs.New(sess)
    input := &ecs.DescribeServicesInput{
        Cluster:  aws.String(clusterARN),
        Services: []*string{aws.String(serviceName)},
    }

    result, err := ecsClient.DescribeServices(input)
    require.NoError(t, err)
    require.NotEmpty(t, result.Services)

    service := result.Services[0]
    assert.Equal(t, *service.RunningCount, *service.DesiredCount)
}
```

---

## Database Testing

### PostgreSQL Connectivity

```go
func testPostgreSQLConnectivity(t *testing.T, opts *terraform.Options) {
    address := terraform.Output(t, opts, "address")
    port := terraform.Output(t, opts, "port")
    dbName := terraform.Output(t, opts, "db_name")

    connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
        address, port, username, password, dbName)

    db, err := sql.Open("postgres", connStr)
    require.NoError(t, err)
    defer db.Close()

    // Test connection
    err = db.Ping()
    require.NoError(t, err)

    // Verify version
    var version string
    err = db.QueryRow("SELECT version()").Scan(&version)
    require.NoError(t, err)
    require.Contains(t, version, "PostgreSQL")
}
```

### Database Operations

```go
func testDatabaseOperations(t *testing.T, db *sql.DB) {
    // Create table
    _, err := db.Exec(`
        CREATE TABLE test_table (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    `)
    require.NoError(t, err)

    // Insert data
    _, err = db.Exec("INSERT INTO test_table (name) VALUES ($1)", "test-record")
    require.NoError(t, err)

    // Query data
    var id int
    var name string
    err = db.QueryRow("SELECT id, name FROM test_table WHERE name = $1", "test-record").
        Scan(&id, &name)
    require.NoError(t, err)
    assert.Equal(t, "test-record", name)

    // Update data
    _, err = db.Exec("UPDATE test_table SET name = $1 WHERE id = $2", "updated", id)
    require.NoError(t, err)

    // Delete data
    _, err = db.Exec("DELETE FROM test_table WHERE id = $1", id)
    require.NoError(t, err)

    // Drop table
    _, err = db.Exec("DROP TABLE test_table")
    require.NoError(t, err)
}
```

---

## Cache Testing

### Redis Connectivity

```go
func testRedisConnectivity(t *testing.T, endpoint, port string) {
    rdb := redis.NewClient(&redis.Options{
        Addr:     fmt.Sprintf("%s:%s", endpoint, port),
        Password: "",
        DB:       0,
    })
    defer rdb.Close()

    ctx := context.Background()

    // Test connection
    err := rdb.Ping(ctx).Err()
    require.NoError(t, err)

    // Get server info
    info, err := rdb.Info(ctx, "server").Result()
    require.NoError(t, err)
    require.Contains(t, info, "redis_version")
}
```

### Redis Operations

```go
func testRedisOperations(t *testing.T, rdb *redis.Client) {
    ctx := context.Background()

    // SET/GET
    err := rdb.Set(ctx, "test:key", "test-value", 0).Err()
    require.NoError(t, err)

    val, err := rdb.Get(ctx, "test:key").Result()
    require.NoError(t, err)
    assert.Equal(t, "test-value", val)

    // Hash operations
    err = rdb.HSet(ctx, "test:hash", "field1", "value1").Err()
    require.NoError(t, err)

    hashVal, err := rdb.HGet(ctx, "test:hash", "field1").Result()
    require.NoError(t, err)
    assert.Equal(t, "value1", hashVal)

    // List operations
    err = rdb.LPush(ctx, "test:list", "item1", "item2").Err()
    require.NoError(t, err)

    listVals, err := rdb.LRange(ctx, "test:list", 0, -1).Result()
    require.NoError(t, err)
    assert.Len(t, listVals, 2)

    // Cleanup
    rdb.Del(ctx, "test:key", "test:hash", "test:list")
}
```

### Redis Persistence

```go
func testRedisPersistence(t *testing.T, endpoint, port string) {
    ctx := context.Background()

    // Client 1: Set key
    rdb1 := redis.NewClient(&redis.Options{
        Addr: fmt.Sprintf("%s:%s", endpoint, port),
    })
    err := rdb1.Set(ctx, "persist:key", "persistent-value", 0).Err()
    require.NoError(t, err)
    rdb1.Close()

    // Client 2: Verify key exists
    rdb2 := redis.NewClient(&redis.Options{
        Addr: fmt.Sprintf("%s:%s", endpoint, port),
    })
    defer rdb2.Close()

    val, err := rdb2.Get(ctx, "persist:key").Result()
    require.NoError(t, err)
    assert.Equal(t, "persistent-value", val)

    rdb2.Del(ctx, "persist:key")
}
```

---

## Service Health Checks

### HTTP Endpoint

```go
func testHTTPEndpoint(t *testing.T, url string) {
    // Simple GET request
    http_helper.HttpGetWithRetry(
        t,
        url,
        nil,
        200,
        "expected content",
        30,             // maxRetries
        5*time.Second,  // retryInterval
    )
}
```

### HTTP with Custom Validation

```go
func testHTTPWithValidation(t *testing.T, url string) {
    http_helper.HttpGetWithRetryWithCustomValidation(
        t,
        url,
        nil,
        30,
        10*time.Second,
        func(status int, body string) bool {
            if status != 200 {
                t.Logf("Got status %d, retrying...", status)
                return false
            }

            // Parse JSON response
            var response map[string]interface{}
            if err := json.Unmarshal([]byte(body), &response); err != nil {
                return false
            }

            // Validate response structure
            if response["status"] == "healthy" {
                t.Log("✅ Service is healthy")
                return true
            }

            return false
        },
    )
}
```

### Load Balancer Health

```go
func testLoadBalancerHealth(t *testing.T, region, albDNS string) {
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(region),
    })
    require.NoError(t, err)

    elbClient := elbv2.New(sess)

    // Find load balancer
    describeInput := &elbv2.DescribeLoadBalancersInput{}
    result, err := elbClient.DescribeLoadBalancers(describeInput)
    require.NoError(t, err)

    var targetLB *elbv2.LoadBalancer
    for _, lb := range result.LoadBalancers {
        if *lb.DNSName == albDNS {
            targetLB = lb
            break
        }
    }

    require.NotNil(t, targetLB)
    assert.Equal(t, "active", *targetLB.State.Code)

    // Check target health
    tgInput := &elbv2.DescribeTargetGroupsInput{
        LoadBalancerArn: targetLB.LoadBalancerArn,
    }
    tgResult, err := elbClient.DescribeTargetGroups(tgInput)
    require.NoError(t, err)

    for _, tg := range tgResult.TargetGroups {
        healthInput := &elbv2.DescribeTargetHealthInput{
            TargetGroupArn: tg.TargetGroupArn,
        }
        healthResult, err := elbClient.DescribeTargetHealth(healthInput)
        require.NoError(t, err)

        healthyCount := 0
        for _, target := range healthResult.TargetHealthDescriptions {
            if *target.TargetHealth.State == "healthy" {
                healthyCount++
            }
        }

        t.Logf("Target group %s: %d healthy targets", *tg.TargetGroupName, healthyCount)
    }
}
```

---

## Helper Functions

### Retry with Timeout

```go
func retryWithTimeout(t *testing.T, timeout time.Duration, fn func() error) {
    deadline := time.Now().Add(timeout)

    for time.Now().Before(deadline) {
        err := fn()
        if err == nil {
            return
        }

        t.Logf("Retry failed: %v", err)
        time.Sleep(10 * time.Second)
    }

    require.Fail(t, "Operation did not succeed within timeout")
}
```

### Wait for Condition

```go
func waitForCondition(t *testing.T, condition func() bool, timeout time.Duration) {
    deadline := time.Now().Add(timeout)

    for time.Now().Before(deadline) {
        if condition() {
            return
        }

        time.Sleep(10 * time.Second)
    }

    require.Fail(t, "Condition not met within timeout")
}
```

### Generate Test Name

```go
func generateTestName(prefix string) string {
    return fmt.Sprintf("%s-%s", prefix, random.UniqueId())
}
```

### Setup AWS Session

```go
func setupAWSSession(t *testing.T, region string) *session.Session {
    sess, err := session.NewSession(&aws.Config{
        Region: aws.String(region),
    })
    require.NoError(t, err)
    return sess
}
```

---

## Common Test Scenarios

### Scenario 1: Minimal Validation

```go
func TestModuleMinimal(t *testing.T) {
    t.Parallel()

    opts := &terraform.Options{
        TerraformDir: "../../examples/tofu/module",
        Vars: map[string]interface{}{
            "name": "test",
        },
    }

    terraform.Init(t, opts)
    terraform.Validate(t, opts)
    terraform.InitAndPlan(t, opts)
}
```

### Scenario 2: Deploy and Validate Outputs

```go
func TestModuleOutputs(t *testing.T) {
    t.Parallel()

    opts := setupTerraform(t)
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Validate all outputs
    outputs := []string{"url", "arn", "sg_id"}
    for _, name := range outputs {
        value := terraform.Output(t, opts, name)
        require.NotEmpty(t, value)
    }
}
```

### Scenario 3: Deploy and Test Connectivity

```go
func TestModuleConnectivity(t *testing.T) {
    t.Parallel()

    opts := setupTerraform(t)
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    endpoint := terraform.Output(t, opts, "endpoint")

    // Test connectivity with retries
    retryWithTimeout(t, 5*time.Minute, func() error {
        return testConnection(endpoint)
    })
}
```

### Scenario 4: Deploy and Test Operations

```go
func TestModuleOperations(t *testing.T) {
    t.Parallel()

    opts := setupTerraform(t)
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    // Connect to service
    client := connectToService(t, opts)
    defer client.Close()

    // Perform operations
    t.Run("CreateOperation", func(t *testing.T) {
        err := client.Create("test-data")
        require.NoError(t, err)
    })

    t.Run("ReadOperation", func(t *testing.T) {
        data, err := client.Read("test-data")
        require.NoError(t, err)
        assert.NotNil(t, data)
    })

    t.Run("DeleteOperation", func(t *testing.T) {
        err := client.Delete("test-data")
        require.NoError(t, err)
    })
}
```

---

## Best Practices

1. **Always use unique names**: `random.UniqueId()` prevents conflicts
2. **Always defer cleanup**: `defer terraform.Destroy()` ensures resources are cleaned up
3. **Use appropriate timeouts**: Different services need different timeouts
4. **Log progress**: Use `t.Logf()` for debugging
5. **Test outputs first**: Validate outputs before testing functionality
6. **Use subtests**: Organize related tests with `t.Run()`
7. **Retry operations**: Use retries for flaky operations
8. **Validate cleanup**: Ensure resources are properly destroyed

---

**Last Updated**: 2025-10-29
**Maintained By**: Platform Team
