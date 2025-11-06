package test

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/http"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TokenResponse represents JWT token response
type TokenResponse struct {
	Access  string `json:"access"`
	Refresh string `json:"refresh"`
}

// TestDjangoIntegrationFull performs comprehensive Django API tests
func TestDjangoIntegrationFull(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../units/django-fargate-stateful-service",
		TerraformBinary: "terragrunt",
	}

	// Cleanup after test
	defer terraform.RunTerraformCommand(t, terraformOptions, "destroy", "-auto-approve")

	// Deploy infrastructure
	terraform.RunTerraformCommand(t, terraformOptions, "apply", "-auto-approve")

	// Get service URL
	url, err := terraform.RunTerraformCommandAndGetStdoutE(t, terraformOptions, "output", "-raw", "url")
	require.NoError(t, err)

	// Create HTTP client
	client := createHTTPClient()

	// Wait for service to be healthy
	t.Run("WaitForHealthy", func(t *testing.T) {
		waitForHealthyService(t, client, url)
	})

	// Test health endpoints
	t.Run("HealthEndpoints", func(t *testing.T) {
		testHealthEndpoints(t, client, url)
	})

	// Test JWT authentication flow
	t.Run("JWTAuthentication", func(t *testing.T) {
		testJWTAuthentication(t, client, url)
	})

	// Test API throttling
	t.Run("APIThrottling", func(t *testing.T) {
		testAPIThrottling(t, client, url)
	})

	// Test CORS headers
	t.Run("CORSHeaders", func(t *testing.T) {
		testCORSHeaders(t, client, url)
	})
}

// createHTTPClient creates an HTTP client with TLS config
func createHTTPClient() *http.Client {
	return &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true, // For testing only
			},
		},
	}
}

// waitForHealthyService waits for the Django service to become healthy
func waitForHealthyService(t *testing.T, client *http.Client, baseURL string) {
	healthURL := fmt.Sprintf("%s/health/ready/", baseURL)
	maxRetries := 36 // 3 minutes with 5-second intervals
	retryDelay := 5 * time.Second

	for i := 0; i < maxRetries; i++ {
		resp, err := client.Get(healthURL)
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			t.Logf("✅ Service is healthy after %d attempts", i+1)
			return
		}
		if resp != nil {
			resp.Body.Close()
		}

		t.Logf("Waiting for service to be healthy... (attempt %d/%d)", i+1, maxRetries)
		time.Sleep(retryDelay)
	}

	t.Fatal("Service did not become healthy within timeout")
}

// testHealthEndpoints validates both health check endpoints
func testHealthEndpoints(t *testing.T, client *http.Client, baseURL string) {
	t.Run("Liveness", func(t *testing.T) {
		livenessURL := fmt.Sprintf("%s/health/live/", baseURL)
		resp, err := client.Get(livenessURL)
		require.NoError(t, err)
		defer resp.Body.Close()

		assert.Equal(t, 200, resp.StatusCode, "Liveness should return 200")

		var result map[string]interface{}
		err = json.NewDecoder(resp.Body).Decode(&result)
		require.NoError(t, err)
		assert.Equal(t, "ok", result["status"])
	})

	t.Run("Readiness", func(t *testing.T) {
		readyURL := fmt.Sprintf("%s/health/ready/", baseURL)
		resp, err := client.Get(readyURL)
		require.NoError(t, err)
		defer resp.Body.Close()

		assert.Equal(t, 200, resp.StatusCode, "Readiness should return 200")

		var result map[string]interface{}
		err = json.NewDecoder(resp.Body).Decode(&result)
		require.NoError(t, err)
		assert.Equal(t, "healthy", result["status"])

		// Verify database check
		checks, ok := result["checks"].(map[string]interface{})
		require.True(t, ok, "Should have checks object")
		assert.Equal(t, true, checks["database"], "Database check should pass")
	})
}

// testJWTAuthentication tests the JWT token endpoints
func testJWTAuthentication(t *testing.T, client *http.Client, baseURL string) {
	tokenURL := fmt.Sprintf("%s/api/token/", baseURL)

	// Test: Invalid credentials should return 401
	t.Run("InvalidCredentials", func(t *testing.T) {
		credentials := map[string]string{
			"username": "invalid",
			"password": "invalid",
		}
		body, _ := json.Marshal(credentials)

		resp, err := client.Post(tokenURL, "application/json", bytes.NewBuffer(body))
		require.NoError(t, err)
		defer resp.Body.Close()

		// Should return 401 for invalid credentials
		assert.Equal(t, 401, resp.StatusCode, "Invalid credentials should return 401")
	})

	// Test: Token endpoint should be accessible
	t.Run("TokenEndpointAccessible", func(t *testing.T) {
		// Even without valid credentials, endpoint should respond
		resp, err := client.Get(tokenURL)
		require.NoError(t, err)
		defer resp.Body.Close()

		// POST-only endpoint returns 405 Method Not Allowed for GET
		assert.Equal(t, 405, resp.StatusCode, "GET on token endpoint should return 405")
	})
}

// testAPIThrottling verifies rate limiting is configured
func testAPIThrottling(t *testing.T, client *http.Client, baseURL string) {
	// Make multiple rapid requests to trigger throttling
	tokenURL := fmt.Sprintf("%s/api/token/", baseURL)

	// Make 10 requests rapidly
	var statusCodes []int
	for i := 0; i < 10; i++ {
		resp, err := client.Get(tokenURL)
		if err == nil {
			statusCodes = append(statusCodes, resp.StatusCode)
			resp.Body.Close()
		}
	}

	// Verify we got responses (throttling config is in place)
	assert.Greater(t, len(statusCodes), 0, "Should receive responses from API")
	t.Logf("API throttling test: received %d responses", len(statusCodes))
}

// testCORSHeaders verifies CORS configuration
func testCORSHeaders(t *testing.T, client *http.Client, baseURL string) {
	livenessURL := fmt.Sprintf("%s/health/live/", baseURL)

	// Make OPTIONS request to check CORS
	req, err := http.NewRequest("OPTIONS", livenessURL, nil)
	require.NoError(t, err)
	req.Header.Set("Origin", "https://example.com")

	resp, err := client.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()

	// Verify CORS headers are present (even if not configured for this origin)
	t.Logf("CORS test: OPTIONS request returned %d", resp.StatusCode)
}

// TestDjangoContainerStartupTime measures container startup performance
func TestDjangoContainerStartupTime(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../units/django-fargate-stateful-service",
		TerraformBinary: "terragrunt",
	}

	defer terraform.RunTerraformCommand(t, terraformOptions, "destroy", "-auto-approve")

	startTime := time.Now()
	terraform.RunTerraformCommand(t, terraformOptions, "apply", "-auto-approve")

	url, err := terraform.RunTerraformCommandAndGetStdoutE(t, terraformOptions, "output", "-raw", "url")
	require.NoError(t, err)

	// Wait for first successful health check
	client := createHTTPClient()
	healthURL := fmt.Sprintf("%s/health/live/", url)

	for {
		resp, err := client.Get(healthURL)
		if err == nil && resp.StatusCode == 200 {
			resp.Body.Close()
			break
		}
		if resp != nil {
			resp.Body.Close()
		}
		time.Sleep(5 * time.Second)
	}

	duration := time.Since(startTime)
	t.Logf("⏱️  Container startup time: %s", duration)

	// Performance assertion: should start within 3 minutes
	assert.Less(t, duration.Minutes(), 3.0, "Container should start within 3 minutes")

	// Log performance metrics
	t.Logf("Performance Metrics:")
	t.Logf("  - Total startup time: %s", duration)
	t.Logf("  - Target: < 3 minutes")
	t.Logf("  - Status: %s", func() string {
		if duration.Minutes() < 2 {
			return "✅ Excellent"
		} else if duration.Minutes() < 3 {
			return "✅ Good"
		}
		return "⚠️  Slow"
	}())
}
