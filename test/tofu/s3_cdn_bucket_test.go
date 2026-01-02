package tofu_test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

// TestModuleS3CdnBucket tests the S3 bucket module configured for CDN use
func TestModuleS3CdnBucket(t *testing.T) {
	t.Parallel()

	bucketName := fmt.Sprintf("cdn-test-%s", strings.ToLower(random.UniqueId()))

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/s3-cdn-bucket",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name": bucketName,
			"cors_allowed_origins": []string{
				"https://example.com",
				"https://test.example.com",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	// Verify outputs
	outputBucketName := terraform.Output(t, terraformOptions, "bucket_name")
	assert.Equal(t, bucketName, outputBucketName)

	// Verify website endpoint is set (indicates website hosting is enabled)
	websiteEndpoint := terraform.Output(t, terraformOptions, "website_endpoint")
	assert.NotEmpty(t, websiteEndpoint, "website_endpoint should be set for CDN buckets")
	assert.Contains(t, websiteEndpoint, "s3-website", "website_endpoint should be an S3 website URL")

	// Verify website domain is set
	websiteDomain := terraform.Output(t, terraformOptions, "website_domain")
	assert.NotEmpty(t, websiteDomain, "website_domain should be set for CDN buckets")

	// Verify regional domain is set
	regionalDomain := terraform.Output(t, terraformOptions, "bucket_regional_domain_name")
	assert.NotEmpty(t, regionalDomain, "bucket_regional_domain_name should be set")
	assert.Contains(t, regionalDomain, "s3", "regional domain should be an S3 domain")
}
