package modules_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/elasticache"
	"github.com/go-redis/redis/v8"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestRedisModule tests the Redis ElastiCache module comprehensively
func TestRedisModule(t *testing.T) {
	t.Parallel()

	// Generate unique identifiers for this test run
	uniqueID := random.UniqueId()
	name := fmt.Sprintf("redis-test-%s", uniqueID)
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/redis",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name":               name,
			"node_type":          "cache.t3.micro", // Use small instance for testing
			"num_cache_nodes":    1,                // Single node for testing
			"automatic_failover": false,            // Disable for single node
			"multi_az":           false,            // Single AZ for cost savings
			"auth_token_enabled": false,            // Simplify connectivity testing
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Cleanup resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the Redis ElastiCache cluster
	t.Log("Deploying Redis ElastiCache cluster... (this may take 5-10 minutes)")
	terraform.InitAndApply(t, terraformOptions)

	// Run test suite
	t.Run("Outputs", func(t *testing.T) {
		testRedisOutputs(t, terraformOptions)
	})

	t.Run("ClusterStatus", func(t *testing.T) {
		testRedisClusterStatus(t, terraformOptions, awsRegion, name)
	})

	t.Run("RedisConnectivity", func(t *testing.T) {
		testRedisConnectivity(t, terraformOptions)
	})

	t.Run("RedisOperations", func(t *testing.T) {
		testRedisOperations(t, terraformOptions)
	})

	t.Run("RedisPersistence", func(t *testing.T) {
		testRedisPersistence(t, terraformOptions)
	})

	t.Run("SecurityGroup", func(t *testing.T) {
		testRedisSecurityGroup(t, terraformOptions)
	})
}

// TestRedisModuleMinimal validates module configuration without deployment
func TestRedisModuleMinimal(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/redis",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name": "test-redis-minimal",
		},
	}

	// Test 1: Init
	t.Run("Init", func(t *testing.T) {
		terraform.Init(t, terraformOptions)
		t.Log("✅ Terraform init successful")
	})

	// Test 2: Validate
	t.Run("Validate", func(t *testing.T) {
		terraform.Validate(t, terraformOptions)
		t.Log("✅ Terraform validate successful")
	})

	// Note: Plan test removed - requires AWS credentials which aren't available in CI
	// For full Plan testing, use the non-Minimal tests which deploy real infrastructure
}

// testRedisOutputs validates that all expected outputs are present
func testRedisOutputs(t *testing.T, opts *terraform.Options) {
	// Verify primary endpoint output
	primaryEndpoint := terraform.Output(t, opts, "primary_endpoint_address")
	require.NotEmpty(t, primaryEndpoint, "Primary endpoint should not be empty")
	require.Contains(t, primaryEndpoint, ".cache.amazonaws.com", "Primary endpoint should be ElastiCache domain")
	t.Logf("✅ Primary endpoint: %s", primaryEndpoint)

	// Verify port output
	port := terraform.Output(t, opts, "port")
	require.NotEmpty(t, port, "Port output should not be empty")
	assert.Equal(t, "6379", port, "Redis should use default port 6379")
	t.Logf("✅ Redis port: %s", port)

	// Verify ARN output
	arn := terraform.Output(t, opts, "arn")
	require.NotEmpty(t, arn, "ARN output should not be empty")
	require.Regexp(t, "^arn:aws:elasticache:", arn, "ARN should be valid ElastiCache ARN")
	t.Logf("✅ Redis ARN: %s", arn)

	// Verify security group output
	sgID := terraform.Output(t, opts, "redis_security_group_id")
	require.NotEmpty(t, sgID, "Security group ID should not be empty")
	require.Regexp(t, "^sg-[a-f0-9]+$", sgID, "Security group ID should be valid")
	t.Logf("✅ Security group: %s", sgID)

	// Verify Redis URL output
	redisURL := terraform.Output(t, opts, "redis_url")
	require.NotEmpty(t, redisURL, "Redis URL should not be empty")
	require.Contains(t, redisURL, "redis://", "Redis URL should have redis:// scheme")
	t.Logf("✅ Redis URL generated")

	// Verify Celery broker URL output
	celeryURL := terraform.Output(t, opts, "celery_broker_url")
	require.NotEmpty(t, celeryURL, "Celery broker URL should not be empty")
	require.Contains(t, celeryURL, "redis://", "Celery broker URL should have redis:// scheme")
	require.Contains(t, celeryURL, "/1", "Celery broker should use database 1")
	t.Logf("✅ Celery broker URL generated")
}

// testRedisClusterStatus verifies the ElastiCache cluster is available
func testRedisClusterStatus(t *testing.T, opts *terraform.Options, region, replicationGroupID string) {
	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err, "Failed to create AWS session")

	ecClient := elasticache.New(sess)

	// Wait for cluster to be available (up to 10 minutes)
	maxRetries := 60
	retryInterval := 10 * time.Second

	var clusterAvailable bool
	for i := 0; i < maxRetries; i++ {
		input := &elasticache.DescribeReplicationGroupsInput{
			ReplicationGroupId: aws.String(replicationGroupID),
		}

		result, err := ecClient.DescribeReplicationGroups(input)
		if err != nil {
			t.Logf("Retry %d/%d: Cluster not found yet: %v", i+1, maxRetries, err)
			time.Sleep(retryInterval)
			continue
		}

		require.NotEmpty(t, result.ReplicationGroups, "No replication groups returned")
		cluster := result.ReplicationGroups[0]

		status := *cluster.Status
		t.Logf("Cluster status: %s (%d/%d)", status, i+1, maxRetries)

		if status == "available" {
			clusterAvailable = true

			// Verify cluster properties
			assert.NotNil(t, cluster.CacheNodeType, "Node type should be set")
			assert.NotEmpty(t, cluster.MemberClusters, "Should have member clusters")
			assert.Equal(t, false, *cluster.ClusterEnabled, "Cluster mode should match configuration")

			t.Logf("✅ Cluster details: NodeType=%s, Members=%d",
				*cluster.CacheNodeType, len(cluster.MemberClusters))
			break
		}

		if status == "deleting" || status == "create-failed" {
			require.Fail(t, "Cluster entered failed state: %s", status)
		}

		time.Sleep(retryInterval)
	}

	require.True(t, clusterAvailable, "ElastiCache cluster did not become available within timeout")
	t.Log("✅ ElastiCache cluster is available")
}

// testRedisConnectivity verifies we can connect to Redis
func testRedisConnectivity(t *testing.T, opts *terraform.Options) {
	endpoint := terraform.Output(t, opts, "primary_endpoint_address")
	port := terraform.Output(t, opts, "port")

	// Create Redis client
	rdb := redis.NewClient(&redis.Options{
		Addr:         fmt.Sprintf("%s:%s", endpoint, port),
		Password:     "", // No password for testing
		DB:           0,  // Use default DB
		DialTimeout:  10 * time.Second,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	})
	defer rdb.Close()

	ctx := context.Background()

	// Try to connect with retries (cluster might be initializing)
	maxRetries := 30
	retryInterval := 10 * time.Second

	var connected bool
	for i := 0; i < maxRetries; i++ {
		err := rdb.Ping(ctx).Err()
		if err == nil {
			connected = true
			t.Log("✅ Successfully connected to Redis cluster")
			break
		}

		t.Logf("Retry %d/%d: Connection failed: %v", i+1, maxRetries, err)
		time.Sleep(retryInterval)
	}

	require.True(t, connected, "Failed to connect to Redis after retries")

	// Verify Redis info
	info, err := rdb.Info(ctx, "server").Result()
	require.NoError(t, err, "Failed to get Redis server info")
	require.Contains(t, info, "redis_version", "Should return Redis version info")
	t.Logf("✅ Redis server info retrieved")
}

// testRedisOperations performs basic Redis operations
func testRedisOperations(t *testing.T, opts *terraform.Options) {
	endpoint := terraform.Output(t, opts, "primary_endpoint_address")
	port := terraform.Output(t, opts, "port")

	// Create Redis client
	rdb := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", endpoint, port),
		Password: "",
		DB:       0,
	})
	defer rdb.Close()

	ctx := context.Background()

	// Test 1: SET operation
	testKey := "test:key"
	testValue := "test-value"
	err := rdb.Set(ctx, testKey, testValue, 0).Err()
	require.NoError(t, err, "Failed to SET key")
	t.Logf("✅ SET operation successful")

	// Test 2: GET operation
	val, err := rdb.Get(ctx, testKey).Result()
	require.NoError(t, err, "Failed to GET key")
	assert.Equal(t, testValue, val, "Retrieved value should match set value")
	t.Logf("✅ GET operation successful: %s", val)

	// Test 3: EXISTS operation
	exists, err := rdb.Exists(ctx, testKey).Result()
	require.NoError(t, err, "Failed to check key existence")
	assert.Equal(t, int64(1), exists, "Key should exist")
	t.Logf("✅ EXISTS operation successful")

	// Test 4: DEL operation
	deleted, err := rdb.Del(ctx, testKey).Result()
	require.NoError(t, err, "Failed to DEL key")
	assert.Equal(t, int64(1), deleted, "Should delete one key")
	t.Logf("✅ DEL operation successful")

	// Test 5: Hash operations (HSET, HGET, HGETALL)
	hashKey := "test:hash"
	err = rdb.HSet(ctx, hashKey, map[string]interface{}{
		"field1": "value1",
		"field2": "value2",
	}).Err()
	require.NoError(t, err, "Failed to HSET")

	hashVal, err := rdb.HGet(ctx, hashKey, "field1").Result()
	require.NoError(t, err, "Failed to HGET")
	assert.Equal(t, "value1", hashVal, "Hash field value should match")
	t.Logf("✅ Hash operations successful")

	// Test 6: List operations (LPUSH, LRANGE)
	listKey := "test:list"
	err = rdb.LPush(ctx, listKey, "item1", "item2", "item3").Err()
	require.NoError(t, err, "Failed to LPUSH")

	listVals, err := rdb.LRange(ctx, listKey, 0, -1).Result()
	require.NoError(t, err, "Failed to LRANGE")
	assert.Len(t, listVals, 3, "List should contain 3 items")
	t.Logf("✅ List operations successful")

	// Test 7: Set operations (SADD, SMEMBERS)
	setKey := "test:set"
	err = rdb.SAdd(ctx, setKey, "member1", "member2", "member3").Err()
	require.NoError(t, err, "Failed to SADD")

	setMembers, err := rdb.SMembers(ctx, setKey).Result()
	require.NoError(t, err, "Failed to SMEMBERS")
	assert.Len(t, setMembers, 3, "Set should contain 3 members")
	t.Logf("✅ Set operations successful")

	// Cleanup test keys
	rdb.Del(ctx, hashKey, listKey, setKey)
}

// testRedisPersistence verifies data persistence across connections
func testRedisPersistence(t *testing.T, opts *terraform.Options) {
	endpoint := terraform.Output(t, opts, "primary_endpoint_address")
	port := terraform.Output(t, opts, "port")

	// Create first Redis client
	rdb1 := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", endpoint, port),
		Password: "",
		DB:       0,
	})

	ctx := context.Background()

	// Set a key with first client
	persistKey := "test:persist"
	persistValue := "persistent-value"
	err := rdb1.Set(ctx, persistKey, persistValue, 0).Err()
	require.NoError(t, err, "Failed to SET key with first client")
	t.Logf("✅ Set key with first client")

	// Close first client
	rdb1.Close()

	// Create second Redis client (new connection)
	rdb2 := redis.NewClient(&redis.Options{
		Addr:     fmt.Sprintf("%s:%s", endpoint, port),
		Password: "",
		DB:       0,
	})
	defer rdb2.Close()

	// Verify key exists with second client
	val, err := rdb2.Get(ctx, persistKey).Result()
	require.NoError(t, err, "Failed to GET key with second client")
	assert.Equal(t, persistValue, val, "Value should persist across connections")
	t.Logf("✅ Data persists across connections")

	// Cleanup
	rdb2.Del(ctx, persistKey)
}

// testRedisSecurityGroup verifies security group configuration
func testRedisSecurityGroup(t *testing.T, opts *terraform.Options) {
	sgID := terraform.Output(t, opts, "redis_security_group_id")

	// Verify security group ID format
	assert.Regexp(t, "^sg-[a-f0-9]+$", sgID, "Security group ID should be valid")
	t.Logf("✅ Security group ID is properly formatted: %s", sgID)
}

// TestRedisCeleryIntegration tests Redis configuration for Celery
func TestRedisCeleryIntegration(t *testing.T) {
	t.Parallel()

	// This test verifies that the Celery broker URL format is correct
	// and uses a different database than the cache

	uniqueID := random.UniqueId()
	name := fmt.Sprintf("redis-celery-%s", uniqueID)

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/redis",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name":      name,
			"node_type": "cache.t3.micro",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Get Redis URLs
	redisURL := terraform.Output(t, terraformOptions, "redis_url")
	celeryURL := terraform.Output(t, terraformOptions, "celery_broker_url")

	// Verify URLs use different databases
	require.Contains(t, redisURL, "/0", "Redis cache should use database 0")
	require.Contains(t, celeryURL, "/1", "Celery broker should use database 1")
	t.Log("✅ Redis cache and Celery broker use separate databases")

	// Verify both can be used simultaneously
	endpoint := terraform.Output(t, terraformOptions, "primary_endpoint_address")
	port := terraform.Output(t, terraformOptions, "port")

	ctx := context.Background()

	// Connect to cache database (0)
	cacheClient := redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", endpoint, port),
		DB:   0,
	})
	defer cacheClient.Close()

	// Connect to Celery database (1)
	celeryClient := redis.NewClient(&redis.Options{
		Addr: fmt.Sprintf("%s:%s", endpoint, port),
		DB:   1,
	})
	defer celeryClient.Close()

	// Write to both databases
	err := cacheClient.Set(ctx, "cache:test", "cache-value", 0).Err()
	require.NoError(t, err)

	err = celeryClient.Set(ctx, "celery:test", "celery-value", 0).Err()
	require.NoError(t, err)

	// Verify isolation (cache client shouldn't see celery key)
	_, err = cacheClient.Get(ctx, "celery:test").Result()
	assert.Error(t, err, "Cache client should not see Celery keys")

	// Verify isolation (celery client shouldn't see cache key)
	_, err = celeryClient.Get(ctx, "cache:test").Result()
	assert.Error(t, err, "Celery client should not see cache keys")

	t.Log("✅ Redis databases are properly isolated")
}
