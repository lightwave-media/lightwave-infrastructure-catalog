package helpers

import (
	"fmt"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

// RetryConfig contains configuration for retry operations
type RetryConfig struct {
	MaxRetries    int
	RetryInterval time.Duration
	Description   string
}

// DefaultRetryConfig returns a sensible default retry configuration
func DefaultRetryConfig() RetryConfig {
	return RetryConfig{
		MaxRetries:    30,
		RetryInterval: 10 * time.Second,
		Description:   "operation",
	}
}

// RetryUntilSuccess retries a function until it returns true or times out
func RetryUntilSuccess(t *testing.T, config RetryConfig, fn func() (bool, error)) {
	t.Helper()

	for i := 0; i < config.MaxRetries; i++ {
		success, err := fn()

		if err != nil {
			t.Logf("Retry %d/%d: %s failed: %v", i+1, config.MaxRetries, config.Description, err)
		} else if success {
			t.Logf("✅ %s succeeded after %d attempts", config.Description, i+1)
			return
		} else {
			t.Logf("Retry %d/%d: %s not ready yet", i+1, config.MaxRetries, config.Description)
		}

		time.Sleep(config.RetryInterval)
	}

	require.Fail(t, fmt.Sprintf("%s did not succeed within timeout (%d retries, %v interval)",
		config.Description, config.MaxRetries, config.RetryInterval))
}

// RetryUntilNoError retries a function until it returns no error or times out
func RetryUntilNoError(t *testing.T, config RetryConfig, fn func() error) {
	t.Helper()

	var lastErr error
	for i := 0; i < config.MaxRetries; i++ {
		err := fn()

		if err == nil {
			t.Logf("✅ %s succeeded after %d attempts", config.Description, i+1)
			return
		}

		lastErr = err
		t.Logf("Retry %d/%d: %s failed: %v", i+1, config.MaxRetries, config.Description, err)
		time.Sleep(config.RetryInterval)
	}

	require.NoError(t, lastErr, "%s did not succeed within timeout", config.Description)
}

// WaitForCondition waits for a condition function to return true
func WaitForCondition(t *testing.T, config RetryConfig, condition func() bool, messageFormat string, args ...interface{}) {
	t.Helper()

	for i := 0; i < config.MaxRetries; i++ {
		if condition() {
			t.Logf("✅ Condition met after %d attempts: "+messageFormat, append([]interface{}{i + 1}, args...)...)
			return
		}

		t.Logf("Retry %d/%d: Waiting for: "+messageFormat, append([]interface{}{i + 1, config.MaxRetries}, args...)...)
		time.Sleep(config.RetryInterval)
	}

	require.Fail(t, fmt.Sprintf("Condition not met within timeout: "+messageFormat, args...))
}

// FastRetryConfig returns a retry config for fast operations (e.g., API calls)
func FastRetryConfig(description string) RetryConfig {
	return RetryConfig{
		MaxRetries:    10,
		RetryInterval: 2 * time.Second,
		Description:   description,
	}
}

// SlowRetryConfig returns a retry config for slow operations (e.g., RDS startup)
func SlowRetryConfig(description string) RetryConfig {
	return RetryConfig{
		MaxRetries:    60,
		RetryInterval: 10 * time.Second,
		Description:   description,
	}
}

// MediumRetryConfig returns a retry config for medium-speed operations (e.g., ECS deployment)
func MediumRetryConfig(description string) RetryConfig {
	return RetryConfig{
		MaxRetries:    30,
		RetryInterval: 10 * time.Second,
		Description:   description,
	}
}
