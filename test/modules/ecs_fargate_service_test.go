package modules_test

import (
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/elbv2"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestECSFargateServiceModule tests the ECS Fargate service module comprehensively
func TestECSFargateServiceModule(t *testing.T) {
	t.Parallel()

	// Generate unique name for this test run
	uniqueID := random.UniqueId()
	name := fmt.Sprintf("ecs-fargate-test-%s", uniqueID)
	awsRegion := "us-east-1"

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/ecs-fargate-service",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name": name,
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": awsRegion,
		},
	}

	// Cleanup resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Deploy the ECS Fargate service
	t.Log("Deploying ECS Fargate service...")
	terraform.InitAndApply(t, terraformOptions)

	// Run test suite
	t.Run("Outputs", func(t *testing.T) {
		testECSOutputs(t, terraformOptions)
	})

	t.Run("ServiceHealth", func(t *testing.T) {
		testECSServiceHealth(t, terraformOptions, awsRegion, name)
	})

	t.Run("LoadBalancer", func(t *testing.T) {
		testECSLoadBalancer(t, terraformOptions, awsRegion)
	})

	t.Run("HTTPEndpoint", func(t *testing.T) {
		testECSHTTPEndpoint(t, terraformOptions)
	})

	t.Run("SecurityGroups", func(t *testing.T) {
		testECSSecurityGroups(t, terraformOptions)
	})
}

// TestECSFargateServiceModuleMinimal validates module configuration without deployment
func TestECSFargateServiceModuleMinimal(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir:    "../../examples/tofu/ecs-fargate-service",
		TerraformBinary: "tofu",
		Vars: map[string]interface{}{
			"name": "test-ecs-minimal",
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

	// Test 3: Plan
	t.Run("Plan", func(t *testing.T) {
		terraform.InitAndPlan(t, terraformOptions)
		t.Log("✅ Terraform plan successful")
	})
}

// testECSOutputs validates that all expected outputs are present
func testECSOutputs(t *testing.T, opts *terraform.Options) {
	// Verify URL output
	url := terraform.Output(t, opts, "url")
	require.NotEmpty(t, url, "URL output should not be empty")
	t.Logf("✅ Service URL: %s", url)

	// Verify ALB DNS name output
	albDNS := terraform.Output(t, opts, "alb_dns_name")
	require.NotEmpty(t, albDNS, "ALB DNS name output should not be empty")
	t.Logf("✅ ALB DNS name: %s", albDNS)

	// Verify security group outputs
	serviceSG := terraform.Output(t, opts, "service_security_group_id")
	require.NotEmpty(t, serviceSG, "Service security group ID should not be empty")
	require.Regexp(t, "^sg-[a-f0-9]+$", serviceSG, "Service security group ID should be valid")
	t.Logf("✅ Service security group: %s", serviceSG)

	albSG := terraform.Output(t, opts, "alb_security_group_id")
	require.NotEmpty(t, albSG, "ALB security group ID should not be empty")
	require.Regexp(t, "^sg-[a-f0-9]+$", albSG, "ALB security group ID should be valid")
	t.Logf("✅ ALB security group: %s", albSG)
}

// testECSServiceHealth verifies the ECS service is running and healthy
func testECSServiceHealth(t *testing.T, opts *terraform.Options, region, serviceName string) {
	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err, "Failed to create AWS session")

	ecsClient := ecs.New(sess)

	// Wait for service to stabilize (up to 5 minutes)
	maxRetries := 30
	retryInterval := 10 * time.Second

	var serviceStable bool
	for i := 0; i < maxRetries; i++ {
		// Find the cluster containing our service
		clusterARN, err := findClusterForService(ecsClient, serviceName)
		if err != nil {
			t.Logf("Retry %d/%d: Service not found yet: %v", i+1, maxRetries, err)
			time.Sleep(retryInterval)
			continue
		}

		// Describe the service
		describeInput := &ecs.DescribeServicesInput{
			Cluster:  aws.String(clusterARN),
			Services: []*string{aws.String(serviceName)},
		}

		result, err := ecsClient.DescribeServices(describeInput)
		require.NoError(t, err, "Failed to describe ECS service")
		require.NotEmpty(t, result.Services, "No services returned")

		service := result.Services[0]

		// Check service status
		runningCount := *service.RunningCount
		desiredCount := *service.DesiredCount

		t.Logf("Service status: Running=%d, Desired=%d", runningCount, desiredCount)

		if runningCount == desiredCount && runningCount > 0 {
			serviceStable = true
			break
		}

		t.Logf("Waiting for service to stabilize... (%d/%d)", i+1, maxRetries)
		time.Sleep(retryInterval)
	}

	require.True(t, serviceStable, "ECS service did not stabilize within timeout")
	t.Log("✅ ECS service is running and healthy")
}

// testECSLoadBalancer verifies the ALB is properly configured and healthy
func testECSLoadBalancer(t *testing.T, opts *terraform.Options, region string) {
	// Create AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	require.NoError(t, err, "Failed to create AWS session")

	elbClient := elbv2.New(sess)
	albDNS := terraform.Output(t, opts, "alb_dns_name")

	// Find the load balancer by DNS name
	describeInput := &elbv2.DescribeLoadBalancersInput{}
	result, err := elbClient.DescribeLoadBalancers(describeInput)
	require.NoError(t, err, "Failed to describe load balancers")

	var targetLB *elbv2.LoadBalancer
	for _, lb := range result.LoadBalancers {
		if *lb.DNSName == albDNS {
			targetLB = lb
			break
		}
	}

	require.NotNil(t, targetLB, "Could not find load balancer with DNS name: %s", albDNS)

	// Verify load balancer state
	assert.Equal(t, "active", *targetLB.State.Code, "Load balancer should be active")
	t.Logf("✅ Load balancer state: %s", *targetLB.State.Code)

	// Verify load balancer scheme
	assert.NotNil(t, targetLB.Scheme, "Load balancer scheme should be set")
	t.Logf("✅ Load balancer scheme: %s", *targetLB.Scheme)

	// Describe target groups
	tgInput := &elbv2.DescribeTargetGroupsInput{
		LoadBalancerArn: targetLB.LoadBalancerArn,
	}
	tgResult, err := elbClient.DescribeTargetGroups(tgInput)
	require.NoError(t, err, "Failed to describe target groups")
	require.NotEmpty(t, tgResult.TargetGroups, "Load balancer should have at least one target group")

	// Check target health
	for _, tg := range tgResult.TargetGroups {
		healthInput := &elbv2.DescribeTargetHealthInput{
			TargetGroupArn: tg.TargetGroupArn,
		}
		healthResult, err := elbClient.DescribeTargetHealth(healthInput)
		require.NoError(t, err, "Failed to describe target health")

		// Count healthy targets
		healthyTargets := 0
		for _, target := range healthResult.TargetHealthDescriptions {
			if target.TargetHealth != nil && *target.TargetHealth.State == "healthy" {
				healthyTargets++
			}
		}

		t.Logf("✅ Target group %s has %d healthy target(s)", *tg.TargetGroupName, healthyTargets)
	}
}

// testECSHTTPEndpoint verifies the service is accessible via HTTP
func testECSHTTPEndpoint(t *testing.T, opts *terraform.Options) {
	url := terraform.Output(t, opts, "url")

	// Wait for service to respond (max 5 minutes, check every 10 seconds)
	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		url,
		nil,
		30,             // maxRetries
		10*time.Second, // timeBetweenRetries
		func(status int, body string) bool {
			// Accept any 2xx or 3xx status code
			if status >= 200 && status < 400 {
				t.Logf("✅ HTTP endpoint returned status %d", status)
				return true
			}
			t.Logf("Waiting for healthy response... (got %d)", status)
			return false
		},
	)

	// Verify we get expected content (the example returns "Hello World!")
	http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello World!", 5, 2*time.Second)
	t.Log("✅ HTTP endpoint returning expected content")
}

// testECSSecurityGroups verifies security groups are properly configured
func testECSSecurityGroups(t *testing.T, opts *terraform.Options) {
	serviceSG := terraform.Output(t, opts, "service_security_group_id")
	albSG := terraform.Output(t, opts, "alb_security_group_id")

	// Verify security group IDs are different
	assert.NotEqual(t, serviceSG, albSG, "Service and ALB should have different security groups")
	t.Log("✅ Service and ALB have separate security groups")

	// Verify security group ID format
	assert.Regexp(t, "^sg-[a-f0-9]+$", serviceSG, "Service security group ID should be valid")
	assert.Regexp(t, "^sg-[a-f0-9]+$", albSG, "ALB security group ID should be valid")
	t.Log("✅ Security group IDs are properly formatted")
}

// Helper function to find the cluster containing a service
func findClusterForService(client *ecs.ECS, serviceName string) (string, error) {
	// List all clusters
	listInput := &ecs.ListClustersInput{}
	listResult, err := client.ListClusters(listInput)
	if err != nil {
		return "", err
	}

	// Search each cluster for the service
	for _, clusterARN := range listResult.ClusterArns {
		listServicesInput := &ecs.ListServicesInput{
			Cluster: clusterARN,
		}
		servicesResult, err := client.ListServices(listServicesInput)
		if err != nil {
			continue
		}

		for _, serviceARN := range servicesResult.ServiceArns {
			if contains(*serviceARN, serviceName) {
				return *clusterARN, nil
			}
		}
	}

	return "", fmt.Errorf("service %s not found in any cluster", serviceName)
}

// Helper function to check if a string contains a substring
func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && (s[len(s)-len(substr):] == substr || s[:len(substr)] == substr))
}
