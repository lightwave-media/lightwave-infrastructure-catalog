package modules_test

import (
	"database/sql"
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/rds"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	_ "github.com/lib/pq" // PostgreSQL driver
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestPostgreSQLModule tests the PostgreSQL RDS module comprehensively
func TestPostgreSQLModule(t *testing.T) {
	t.Parallel()

	// Generate unique identifiers for this test run
	uniqueID := random.UniqueId()
	name := fmt.Sprintf("pg-test-%s", uniqueID)
	dbName := fmt.Sprintf("testdb%s", uniqueID)
	username := "testadmin"
	password := "TestPassword123!" // In real tests, use secure generation
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/postgresql",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name":              name,
			"db_name":           dbName,
			"master_username":   username,
			"master_password":   password,
			"instance_class":    "db.t3.micro", // Use small instance for testing
			"allocated_storage": 20,            // Minimum for testing
			"multi_az":          false,         // Single AZ for cost savings in tests
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Cleanup resources after test (RDS deletion can take 5-10 minutes)
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the PostgreSQL RDS instance
	t.Log("Deploying PostgreSQL RDS instance... (this may take 5-10 minutes)")
	terraform.InitAndApply(t, terraformOptions)

	// Run test suite
	t.Run("Outputs", func(t *testing.T) {
		testPostgreSQLOutputs(t, terraformOptions)
	})

	t.Run("InstanceStatus", func(t *testing.T) {
		testPostgreSQLInstanceStatus(t, terraformOptions, awsRegion, name)
	})

	t.Run("DatabaseConnectivity", func(t *testing.T) {
		testPostgreSQLConnectivity(t, terraformOptions, username, password, dbName)
	})

	t.Run("DatabaseOperations", func(t *testing.T) {
		testPostgreSQLOperations(t, terraformOptions, username, password, dbName)
	})

	t.Run("SecurityGroup", func(t *testing.T) {
		testPostgreSQLSecurityGroup(t, terraformOptions)
	})

	t.Run("BackupConfiguration", func(t *testing.T) {
		testPostgreSQLBackups(t, terraformOptions, awsRegion, name)
	})
}

// TestPostgreSQLModuleMinimal validates module configuration without deployment
func TestPostgreSQLModuleMinimal(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/postgresql",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name":            "test-pg-minimal",
			"db_name":         "testdb",
			"master_username": "testadmin",
			"master_password": "TestPassword123!",
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

// testPostgreSQLOutputs validates that all expected outputs are present
func testPostgreSQLOutputs(t *testing.T, opts *terraform.Options) {
	// Verify endpoint output
	endpoint := terraform.Output(t, opts, "endpoint")
	require.NotEmpty(t, endpoint, "Endpoint output should not be empty")
	require.Contains(t, endpoint, "rds.amazonaws.com", "Endpoint should be RDS domain")
	t.Logf("✅ Database endpoint: %s", endpoint)

	// Verify address output
	address := terraform.Output(t, opts, "address")
	require.NotEmpty(t, address, "Address output should not be empty")
	require.Contains(t, address, "rds.amazonaws.com", "Address should be RDS domain")
	t.Logf("✅ Database address: %s", address)

	// Verify port output
	port := terraform.Output(t, opts, "port")
	require.NotEmpty(t, port, "Port output should not be empty")
	assert.Equal(t, "5432", port, "PostgreSQL should use default port 5432")
	t.Logf("✅ Database port: %s", port)

	// Verify db_name output
	dbName := terraform.Output(t, opts, "db_name")
	require.NotEmpty(t, dbName, "DB name output should not be empty")
	t.Logf("✅ Database name: %s", dbName)

	// Verify ARN output
	arn := terraform.Output(t, opts, "arn")
	require.NotEmpty(t, arn, "ARN output should not be empty")
	require.Regexp(t, "^arn:aws:rds:", arn, "ARN should be valid RDS ARN")
	t.Logf("✅ Database ARN: %s", arn)

	// Verify security group output
	sgID := terraform.Output(t, opts, "db_security_group_id")
	require.NotEmpty(t, sgID, "Security group ID should not be empty")
	require.Regexp(t, "^sg-[a-f0-9]+$", sgID, "Security group ID should be valid")
	t.Logf("✅ Security group: %s", sgID)

	// Verify connection string output
	connString := terraform.Output(t, opts, "connection_string")
	require.NotEmpty(t, connString, "Connection string should not be empty")
	require.Contains(t, connString, "postgresql://", "Connection string should be PostgreSQL URL")
	t.Logf("✅ Connection string generated")
}

// testPostgreSQLInstanceStatus verifies the RDS instance is available
func testPostgreSQLInstanceStatus(t *testing.T, opts *terraform.Options, region, dbIdentifier string) {
	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err, "Failed to create AWS session")

	rdsClient := rds.New(sess)

	// Wait for instance to be available (up to 10 minutes)
	maxRetries := 60
	retryInterval := 10 * time.Second

	var instanceAvailable bool
	for i := 0; i < maxRetries; i++ {
		input := &rds.DescribeDBInstancesInput{
			DBInstanceIdentifier: aws.String(dbIdentifier),
		}

		result, err := rdsClient.DescribeDBInstances(input)
		if err != nil {
			t.Logf("Retry %d/%d: Instance not found yet: %v", i+1, maxRetries, err)
			time.Sleep(retryInterval)
			continue
		}

		require.NotEmpty(t, result.DBInstances, "No DB instances returned")
		instance := result.DBInstances[0]

		status := *instance.DBInstanceStatus
		t.Logf("Instance status: %s (%d/%d)", status, i+1, maxRetries)

		if status == "available" {
			instanceAvailable = true

			// Verify instance properties
			assert.Equal(t, "postgres", *instance.Engine, "Engine should be PostgreSQL")
			assert.NotNil(t, instance.EngineVersion, "Engine version should be set")
			assert.NotNil(t, instance.DBInstanceClass, "Instance class should be set")

			t.Logf("✅ Instance details: Engine=%s %s, Class=%s",
				*instance.Engine, *instance.EngineVersion, *instance.DBInstanceClass)
			break
		}

		if status == "failed" || status == "deleted" {
			require.Fail(t, "Instance entered failed state: %s", status)
		}

		time.Sleep(retryInterval)
	}

	require.True(t, instanceAvailable, "RDS instance did not become available within timeout")
	t.Log("✅ RDS instance is available")
}

// testPostgreSQLConnectivity verifies we can connect to the database
func testPostgreSQLConnectivity(t *testing.T, opts *terraform.Options, username, password, dbName string) {
	address := terraform.Output(t, opts, "address")
	port := terraform.Output(t, opts, "port")

	// Build connection string
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		address, port, username, password, dbName)

	// Try to connect with retries (database might be initializing)
	maxRetries := 30
	retryInterval := 10 * time.Second

	var db *sql.DB
	var err error

	for i := 0; i < maxRetries; i++ {
		db, err = sql.Open("postgres", connStr)
		if err != nil {
			t.Logf("Retry %d/%d: Failed to open connection: %v", i+1, maxRetries, err)
			time.Sleep(retryInterval)
			continue
		}

		err = db.Ping()
		if err == nil {
			t.Log("✅ Successfully connected to PostgreSQL database")
			break
		}

		t.Logf("Retry %d/%d: Connection failed: %v", i+1, maxRetries, err)
		db.Close()
		time.Sleep(retryInterval)
	}

	require.NoError(t, err, "Failed to connect to database after retries")
	defer db.Close()

	// Verify connection is working
	var version string
	err = db.QueryRow("SELECT version()").Scan(&version)
	require.NoError(t, err, "Failed to query database version")
	require.Contains(t, version, "PostgreSQL", "Should return PostgreSQL version")
	t.Logf("✅ Database version: %s", version)
}

// testPostgreSQLOperations performs basic database operations
func testPostgreSQLOperations(t *testing.T, opts *terraform.Options, username, password, dbName string) {
	address := terraform.Output(t, opts, "address")
	port := terraform.Output(t, opts, "port")

	// Connect to database
	connStr := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=require",
		address, port, username, password, dbName)

	db, err := sql.Open("postgres", connStr)
	require.NoError(t, err, "Failed to open database connection")
	defer db.Close()

	// Test 1: Create table
	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS test_table (
			id SERIAL PRIMARY KEY,
			name VARCHAR(100),
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)
	`)
	require.NoError(t, err, "Failed to create test table")
	t.Log("✅ Created test table")

	// Test 2: Insert data
	_, err = db.Exec("INSERT INTO test_table (name) VALUES ($1)", "test-record")
	require.NoError(t, err, "Failed to insert test data")
	t.Log("✅ Inserted test data")

	// Test 3: Query data
	var id int
	var name string
	var createdAt time.Time
	err = db.QueryRow("SELECT id, name, created_at FROM test_table WHERE name = $1", "test-record").
		Scan(&id, &name, &createdAt)
	require.NoError(t, err, "Failed to query test data")
	assert.Equal(t, "test-record", name, "Retrieved data should match inserted data")
	t.Logf("✅ Queried test data: id=%d, name=%s, created_at=%s", id, name, createdAt)

	// Test 4: Update data
	_, err = db.Exec("UPDATE test_table SET name = $1 WHERE id = $2", "updated-record", id)
	require.NoError(t, err, "Failed to update test data")
	t.Log("✅ Updated test data")

	// Test 5: Delete data
	_, err = db.Exec("DELETE FROM test_table WHERE id = $1", id)
	require.NoError(t, err, "Failed to delete test data")
	t.Log("✅ Deleted test data")

	// Test 6: Drop table
	_, err = db.Exec("DROP TABLE test_table")
	require.NoError(t, err, "Failed to drop test table")
	t.Log("✅ Dropped test table")
}

// testPostgreSQLSecurityGroup verifies security group configuration
func testPostgreSQLSecurityGroup(t *testing.T, opts *terraform.Options) {
	sgID := terraform.Output(t, opts, "db_security_group_id")

	// Verify security group ID format
	assert.Regexp(t, "^sg-[a-f0-9]+$", sgID, "Security group ID should be valid")
	t.Logf("✅ Security group ID is properly formatted: %s", sgID)
}

// testPostgreSQLBackups verifies backup configuration
func testPostgreSQLBackups(t *testing.T, opts *terraform.Options, region, dbIdentifier string) {
	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err, "Failed to create AWS session")

	rdsClient := rds.New(sess)

	// Describe DB instance
	input := &rds.DescribeDBInstancesInput{
		DBInstanceIdentifier: aws.String(dbIdentifier),
	}

	result, err := rdsClient.DescribeDBInstances(input)
	require.NoError(t, err, "Failed to describe DB instance")
	require.NotEmpty(t, result.DBInstances, "No DB instances returned")

	instance := result.DBInstances[0]

	// Verify backup retention period
	assert.NotNil(t, instance.BackupRetentionPeriod, "Backup retention period should be set")
	assert.Greater(t, *instance.BackupRetentionPeriod, int64(0), "Backup retention should be enabled")
	t.Logf("✅ Backup retention period: %d days", *instance.BackupRetentionPeriod)

	// Verify automated backups are enabled
	assert.NotNil(t, instance.PreferredBackupWindow, "Preferred backup window should be set")
	t.Logf("✅ Backup window: %s", *instance.PreferredBackupWindow)

	// Verify maintenance window
	assert.NotNil(t, instance.PreferredMaintenanceWindow, "Maintenance window should be set")
	t.Logf("✅ Maintenance window: %s", *instance.PreferredMaintenanceWindow)
}
