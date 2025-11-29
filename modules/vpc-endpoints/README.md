# VPC Endpoints Terraform Module

Creates VPC endpoints for AWS services to enable private connectivity from VPC resources without requiring NAT Gateway or Internet Gateway.

## Purpose

This module solves the common problem of ECS Fargate tasks in private subnets needing to access AWS services like:
- **Secrets Manager** (pull application secrets)
- **ECR** (pull Docker images)
- **S3** (ECR image layers)
- **CloudWatch Logs** (send application logs)

**Why VPC Endpoints?**
- ✅ More cost-effective than NAT Gateway (~$28/month vs ~$32/month)
- ✅ More secure (no internet routing)
- ✅ Lower latency (private AWS backbone)
- ✅ No data transfer charges to AWS services

## Resources Created

- Security group for VPC endpoints (allows HTTPS from VPC CIDR)
- Secrets Manager interface endpoint (optional, enabled by default)
- ECR API interface endpoint (optional, enabled by default)
- ECR DKR interface endpoint (optional, enabled by default)
- S3 gateway endpoint (optional, enabled by default, **FREE**)
- CloudWatch Logs interface endpoint (optional, enabled by default)

## Cost Estimate

**Interface Endpoints**: ~$7.20/month each
- Secrets Manager: $7.20/month
- ECR API: $7.20/month
- ECR DKR: $7.20/month
- CloudWatch Logs: $7.20/month

**Gateway Endpoints**: FREE
- S3: $0/month

**Total**: ~$28.80/month for all interface endpoints + $0 for S3

## Usage

```hcl
module "vpc_endpoints" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/vpc-endpoints?ref=v1.0.0"

  name                     = "my-app-prod"
  vpc_id                   = "vpc-12345678"
  vpc_cidr                 = "10.0.0.0/16"
  private_subnet_ids       = ["subnet-abcd1234", "subnet-efgh5678"]
  private_route_table_ids  = ["rtb-12345678"]

  environment = "prod"

  # All endpoints enabled by default, but can be toggled individually
  enable_secretsmanager = true
  enable_ecr            = true
  enable_s3             = true
  enable_logs           = true

  tags = {
    Project = "my-app"
    Owner   = "platform-team"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| name | Name prefix for VPC endpoints and security group | string | n/a | yes |
| vpc_id | VPC ID where endpoints will be created | string | n/a | yes |
| vpc_cidr | VPC CIDR block for security group ingress rules | string | n/a | yes |
| private_subnet_ids | List of private subnet IDs for interface endpoints | list(string) | n/a | yes |
| private_route_table_ids | List of private route table IDs for S3 gateway endpoint | list(string) | n/a | yes |
| aws_region | AWS region for endpoint service names | string | "us-east-1" | no |
| environment | Environment name (dev, staging, prod) | string | "prod" | no |
| enable_secretsmanager | Enable Secrets Manager VPC endpoint | bool | true | no |
| enable_ecr | Enable ECR VPC endpoints (API and DKR) | bool | true | no |
| enable_s3 | Enable S3 VPC endpoint (gateway, free) | bool | true | no |
| enable_logs | Enable CloudWatch Logs VPC endpoint | bool | true | no |
| tags | A map of tags to apply to all resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_endpoints_security_group_id | Security group ID for VPC endpoints |
| secretsmanager_endpoint_id | ID of the Secrets Manager VPC endpoint |
| secretsmanager_endpoint_dns_names | DNS names of the Secrets Manager VPC endpoint |
| ecr_api_endpoint_id | ID of the ECR API VPC endpoint |
| ecr_dkr_endpoint_id | ID of the ECR DKR VPC endpoint |
| s3_endpoint_id | ID of the S3 VPC endpoint (gateway) |
| logs_endpoint_id | ID of the CloudWatch Logs VPC endpoint |

## Example: ECS Fargate with Private Subnets

This module is particularly useful for ECS Fargate deployments in private subnets:

```hcl
# 1. Create VPC endpoints
module "vpc_endpoints" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/vpc-endpoints?ref=v1.0.0"

  name                     = "my-app-prod"
  vpc_id                   = module.vpc.vpc_id
  vpc_cidr                 = "10.0.0.0/16"
  private_subnet_ids       = module.vpc.private_subnet_ids
  private_route_table_ids  = module.vpc.private_route_table_ids
  environment              = "prod"
}

# 2. Deploy ECS service in private subnets
module "ecs_service" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/django-fargate-service?ref=v1.0.0"

  # ... service configuration ...

  # ECS tasks can now access AWS services privately
  private_subnet_ids = module.vpc.private_subnet_ids
}
```

## Notes

- **Private DNS**: All interface endpoints have private DNS enabled, so your applications automatically use the endpoints without code changes
- **Security Group**: The module creates a security group that allows HTTPS (443) from the VPC CIDR block
- **S3 Gateway Endpoint**: Free and added to private route tables automatically
- **Regional**: Endpoint service names are region-specific (e.g., `com.amazonaws.us-east-1.secretsmanager`)

## Troubleshooting

### ECS Tasks Can't Pull Secrets
- Verify Secrets Manager endpoint is enabled (`enable_secretsmanager = true`)
- Check task execution role has `secretsmanager:GetSecretValue` permission
- Verify security group allows HTTPS from task subnets

### ECS Tasks Can't Pull Docker Images
- Verify ECR endpoints are enabled (`enable_ecr = true`)
- Verify S3 endpoint is enabled (`enable_s3 = true`) - needed for image layers
- Check task execution role has ECR pull permissions

### Logs Not Appearing in CloudWatch
- Verify Logs endpoint is enabled (`enable_logs = true`)
- Check task execution role has CloudWatch Logs permissions

## References

- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [AWS PrivateLink Pricing](https://aws.amazon.com/privatelink/pricing/)
- [ECS Task Networking](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-networking.html)
