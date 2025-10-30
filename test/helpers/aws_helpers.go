package helpers

import (
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/elasticache"
	"github.com/aws/aws-sdk-go/service/rds"
	"github.com/stretchr/testify/require"
)

// AWSSessionConfig contains configuration for AWS session creation
type AWSSessionConfig struct {
	Region  string
	Profile string
}

// GetAWSSession creates an AWS session with the provided configuration
func GetAWSSession(t *testing.T, config AWSSessionConfig) *session.Session {
	t.Helper()

	awsConfig := &aws.Config{
		Region: aws.String(config.Region),
	}

	// Add profile if specified
	if config.Profile != "" {
		// Note: Profile configuration requires AWS_SDK_LOAD_CONFIG=1 environment variable
		awsConfig.CredentialsChainVerboseErrors = aws.Bool(true)
	}

	sess, err := session.NewSession(awsConfig)
	require.NoError(t, err, "Failed to create AWS session")

	return sess
}

// WaitForRDSInstanceAvailable waits for an RDS instance to become available
func WaitForRDSInstanceAvailable(t *testing.T, sess *session.Session, dbIdentifier string, timeout time.Duration) {
	t.Helper()

	rdsClient := rds.New(sess)
	maxRetries := int(timeout / (10 * time.Second))
	retryInterval := 10 * time.Second

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

		if len(result.DBInstances) > 0 {
			status := *result.DBInstances[0].DBInstanceStatus
			t.Logf("RDS instance status: %s (%d/%d)", status, i+1, maxRetries)

			if status == "available" {
				return
			}

			if status == "failed" || status == "deleted" {
				require.Fail(t, fmt.Sprintf("RDS instance entered failed state: %s", status))
			}
		}

		time.Sleep(retryInterval)
	}

	require.Fail(t, "RDS instance did not become available within timeout")
}

// WaitForElastiCacheAvailable waits for an ElastiCache replication group to become available
func WaitForElastiCacheAvailable(t *testing.T, sess *session.Session, replicationGroupID string, timeout time.Duration) {
	t.Helper()

	ecClient := elasticache.New(sess)
	maxRetries := int(timeout / (10 * time.Second))
	retryInterval := 10 * time.Second

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

		if len(result.ReplicationGroups) > 0 {
			status := *result.ReplicationGroups[0].Status
			t.Logf("ElastiCache cluster status: %s (%d/%d)", status, i+1, maxRetries)

			if status == "available" {
				return
			}

			if status == "deleting" || status == "create-failed" {
				require.Fail(t, fmt.Sprintf("ElastiCache cluster entered failed state: %s", status))
			}
		}

		time.Sleep(retryInterval)
	}

	require.Fail(t, "ElastiCache cluster did not become available within timeout")
}

// WaitForECSServiceStable waits for an ECS service to reach desired count
func WaitForECSServiceStable(t *testing.T, sess *session.Session, clusterARN, serviceName string, timeout time.Duration) {
	t.Helper()

	ecsClient := ecs.New(sess)
	maxRetries := int(timeout / (10 * time.Second))
	retryInterval := 10 * time.Second

	for i := 0; i < maxRetries; i++ {
		input := &ecs.DescribeServicesInput{
			Cluster:  aws.String(clusterARN),
			Services: []*string{aws.String(serviceName)},
		}

		result, err := ecsClient.DescribeServices(input)
		if err != nil {
			t.Logf("Retry %d/%d: Service not found yet: %v", i+1, maxRetries, err)
			time.Sleep(retryInterval)
			continue
		}

		if len(result.Services) > 0 {
			service := result.Services[0]
			runningCount := *service.RunningCount
			desiredCount := *service.DesiredCount

			t.Logf("ECS service: Running=%d, Desired=%d (%d/%d)", runningCount, desiredCount, i+1, maxRetries)

			if runningCount == desiredCount && runningCount > 0 {
				return
			}
		}

		time.Sleep(retryInterval)
	}

	require.Fail(t, "ECS service did not stabilize within timeout")
}

// GetVPCIDByTag finds a VPC ID by tag key and value
func GetVPCIDByTag(t *testing.T, sess *session.Session, tagKey, tagValue string) string {
	t.Helper()

	ec2Client := ec2.New(sess)

	input := &ec2.DescribeVpcsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String(fmt.Sprintf("tag:%s", tagKey)),
				Values: []*string{aws.String(tagValue)},
			},
		},
	}

	result, err := ec2Client.DescribeVpcs(input)
	require.NoError(t, err, "Failed to describe VPCs")
	require.NotEmpty(t, result.Vpcs, "No VPCs found with tag %s=%s", tagKey, tagValue)

	return *result.Vpcs[0].VpcId
}

// GetSubnetIDsByTag finds subnet IDs by tag key and value
func GetSubnetIDsByTag(t *testing.T, sess *session.Session, tagKey, tagValue string) []string {
	t.Helper()

	ec2Client := ec2.New(sess)

	input := &ec2.DescribeSubnetsInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String(fmt.Sprintf("tag:%s", tagKey)),
				Values: []*string{aws.String(tagValue)},
			},
		},
	}

	result, err := ec2Client.DescribeSubnets(input)
	require.NoError(t, err, "Failed to describe subnets")
	require.NotEmpty(t, result.Subnets, "No subnets found with tag %s=%s", tagKey, tagValue)

	subnetIDs := make([]string, len(result.Subnets))
	for i, subnet := range result.Subnets {
		subnetIDs[i] = *subnet.SubnetId
	}

	return subnetIDs
}

// ValidateSecurityGroupID validates that a security group ID has the correct format
func ValidateSecurityGroupID(t *testing.T, sgID string) {
	t.Helper()
	require.Regexp(t, "^sg-[a-f0-9]+$", sgID, "Security group ID should be valid")
}

// ValidateResourceARN validates that an ARN has the correct format
func ValidateResourceARN(t *testing.T, arn, service string) {
	t.Helper()
	require.Regexp(t, fmt.Sprintf("^arn:aws:%s:", service), arn, "ARN should be valid %s ARN", service)
}
