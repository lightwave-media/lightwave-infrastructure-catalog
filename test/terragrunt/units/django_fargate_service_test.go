package terragrunt_units_test

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// HealthResponse represents the JSON response from health endpoints
type HealthResponse struct {
	Status string                 `json:"status"`
	Checks map[string]interface{} `json:"checks,omitempty"`
}

// TestUnitDjangoFargateService tests the Django Fargate service deployment
func TestUnitDjangoFargateService(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../../units/django-fargate-stateful-service",
		TerraformBinary: "terragrunt",
	}

	// Cleanup resources after test
	defer terraform.RunTerraformCommand(t, terraformOptions, "destroy", "-auto-approve")

	// Deploy the Django service
	terraform.RunTerraformCommand(t, terraformOptions, "apply", "-auto-approve")

	// Get the ALB URL from Terraform outputs
	url, err := terraform.RunTerraformCommandAndGetStdoutE(t, terraformOptions, "output", "-raw", "url")
	require.NoError(t, err)

	startTime := time.Now()

	// Test 1: Liveness endpoint
	t.Run("Liveness", func(t *testing.T) {
		testLivenessEndpoint(t, url)
	})

	// Test 2: Readiness endpoint
	t.Run("Readiness", func(t *testing.T) {
		testReadinessEndpoint(t, url)
	})

	// Test 3: Service startup time
	duration := time.Since(startTime)
	t.Logf("Django service started in %s", duration)
	assert.Less(t, duration.Seconds(), 180.0, "Service should start within 3 minutes")
}

// testLivenessEndpoint validates the /health/live/ endpoint
func testLivenessEndpoint(t *testing.T, baseURL string) {
	healthURL := fmt.Sprintf("%s/health/live/", baseURL)

	// Wait for service to be ready (max 3 minutes, check every 10 seconds)
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		healthURL,
		&tls.Config{},
		18,                // maxRetries
		10*time.Second,    // timeBetweenRetries
		func(status int, body string) bool {
			// Validate status code
			if status != 200 {
				t.Logf("Liveness check failed with status %d, retrying...", status)
				return false
			}

			// Parse JSON response
			var healthResp HealthResponse
			if err := json.Unmarshal([]byte(body), &healthResp); err != nil {
				t.Logf("Failed to parse liveness response: %v", err)
				return false
			}

			// Validate response structure
			assert.Equal(t, "ok", healthResp.Status, "Liveness status should be 'ok'")
			t.Logf("✅ Liveness check passed: %s", body)
			return true
		},
	)
}

// testReadinessEndpoint validates the /health/ready/ endpoint
func testReadinessEndpoint(t *testing.T, baseURL string) {
	readyURL := fmt.Sprintf("%s/health/ready/", baseURL)

	// Create HTTP client
	tlsConfig := &tls.Config{}
	client := &http.Client{
		Timeout: 10 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}

	// Make request to readiness endpoint
	resp, err := client.Get(readyURL)
	require.NoError(t, err, "Readiness endpoint should be accessible")
	defer resp.Body.Close()

	// Validate status code
	assert.Equal(t, 200, resp.StatusCode, "Readiness endpoint should return 200")

	// Parse JSON response
	var healthResp HealthResponse
	err = json.NewDecoder(resp.Body).Decode(&healthResp)
	require.NoError(t, err, "Should parse readiness JSON response")

	// Validate response structure
	assert.Equal(t, "healthy", healthResp.Status, "Readiness status should be 'healthy'")
	assert.NotNil(t, healthResp.Checks, "Readiness should include checks")

	// Validate database check
	if healthResp.Checks != nil {
		assert.Contains(t, healthResp.Checks, "database", "Should check database connectivity")
		assert.Equal(t, true, healthResp.Checks["database"], "Database should be accessible")
	}

	t.Logf("✅ Readiness check passed: database=%v, cache=%v",
		healthResp.Checks["database"],
		healthResp.Checks["cache"])
}

// TestDjangoModuleMinimal tests the Django Fargate module with minimal configuration
func TestDjangoModuleMinimal(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../../../modules/django-fargate-service",
		Vars: map[string]interface{}{
			"name":                   "test-django-minimal",
			"desired_count":          1,
			"cpu":                    256,
			"memory":                 512,
			"ecr_repository_url":     "123456789012.dkr.ecr.us-east-1.amazonaws.com/test",
			"image_tag":              "latest",
			"django_secret_key_arn":  "arn:aws:secretsmanager:us-east-1:123456789012:secret:test",
			"django_allowed_hosts":   "*.amazonaws.com",
			"database_url":           "postgresql://test:test@localhost:5432/test",
		},
	}

	// Validate Terraform configuration
	t.Run("Init", func(t *testing.T) {
		terraform.Init(t, terraformOptions)
		t.Logf("✅ Terraform init successful")
	})

	t.Run("Validate", func(t *testing.T) {
		terraform.Validate(t, terraformOptions)
		t.Logf("✅ Terraform validate successful")
	})

	t.Run("Plan", func(t *testing.T) {
		terraform.InitAndPlan(t, terraformOptions)
		t.Logf("✅ Terraform plan successful")
	})
}
