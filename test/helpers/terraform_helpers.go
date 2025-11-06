package helpers

import (
	"fmt"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/require"
)

// TerraformTestConfig contains common configuration for Terraform tests
type TerraformTestConfig struct {
	TerraformDir    string
	TerraformBinary string
	Vars            map[string]interface{}
	EnvVars         map[string]string
}

// NewTerraformOptions creates Terraform options from config
func NewTerraformOptions(config TerraformTestConfig) *terraform.Options {
	return &terraform.Options{
		TerraformDir:    config.TerraformDir,
		TerraformBinary: config.TerraformBinary,
		Vars:            config.Vars,
		EnvVars:         config.EnvVars,
	}
}

// ValidateModuleWithoutDeploy runs init, validate, and plan without deploying
func ValidateModuleWithoutDeploy(t *testing.T, opts *terraform.Options) {
	t.Helper()

	// Test 1: Init
	t.Run("Init", func(t *testing.T) {
		terraform.Init(t, opts)
		t.Log("✅ Terraform init successful")
	})

	// Test 2: Validate
	t.Run("Validate", func(t *testing.T) {
		terraform.Validate(t, opts)
		t.Log("✅ Terraform validate successful")
	})

	// Test 3: Plan
	t.Run("Plan", func(t *testing.T) {
		terraform.InitAndPlan(t, opts)
		t.Log("✅ Terraform plan successful")
	})
}

// ValidateRequiredOutputs checks that all required outputs are present and not empty
func ValidateRequiredOutputs(t *testing.T, opts *terraform.Options, outputs []string) {
	t.Helper()

	for _, output := range outputs {
		value := terraform.Output(t, opts, output)
		require.NotEmpty(t, value, "Output '%s' should not be empty", output)
		t.Logf("✅ Output '%s': %s", output, value)
	}
}

// ValidateOutputFormat validates that an output matches a specific pattern
func ValidateOutputFormat(t *testing.T, opts *terraform.Options, output, pattern, description string) {
	t.Helper()

	value := terraform.Output(t, opts, output)
	require.NotEmpty(t, value, "Output '%s' should not be empty", output)
	require.Regexp(t, pattern, value, "%s", description)
	t.Logf("✅ Output '%s' matches expected format: %s", output, value)
}

// GetOutputMap retrieves multiple outputs as a map
func GetOutputMap(t *testing.T, opts *terraform.Options, outputs []string) map[string]string {
	t.Helper()

	result := make(map[string]string)
	for _, output := range outputs {
		result[output] = terraform.Output(t, opts, output)
	}

	return result
}

// DeployAndTest deploys infrastructure and runs test functions
func DeployAndTest(t *testing.T, opts *terraform.Options, tests map[string]func(*testing.T)) {
	t.Helper()

	// Deploy infrastructure
	defer terraform.Destroy(t, opts)
	terraform.InitAndApply(t, opts)

	// Run tests
	for name, testFunc := range tests {
		t.Run(name, func(t *testing.T) {
			testFunc(t)
		})
	}
}

// PrintTerraformOutputs prints all Terraform outputs for debugging
func PrintTerraformOutputs(t *testing.T, opts *terraform.Options) {
	t.Helper()

	outputs := terraform.OutputAll(t, opts)
	t.Log("=== Terraform Outputs ===")
	for key, value := range outputs {
		t.Logf("  %s: %v", key, value)
	}
}

// GetModuleTestDefaults returns default configuration for module tests
func GetModuleTestDefaults(modulePath, uniqueID string) TerraformTestConfig {
	return TerraformTestConfig{
		TerraformDir:    modulePath,
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name": fmt.Sprintf("test-%s", uniqueID),
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
		},
	}
}

// GetUnitTestDefaults returns default configuration for unit (Terragrunt) tests
func GetUnitTestDefaults(unitPath string) TerraformTestConfig {
	return TerraformTestConfig{
		TerraformDir:    unitPath,
		TerraformBinary: "terragrunt",
		Vars:            map[string]interface{}{},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "us-east-1",
			"AWS_PROFILE":        "lightwave-admin-new",
		},
	}
}
