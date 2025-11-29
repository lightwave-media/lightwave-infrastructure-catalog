# ---------------------------------------------------------------------------------------------------------------------
# CREATE SECURITY GROUP FOR VPC ENDPOINTS
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-vpc-endpoints"
      Environment = var.environment
    }
  )
}

# Allow inbound HTTPS from VPC CIDR
module "allow_https_from_vpc" {
  source = "../sg-rule"

  security_group_id = aws_security_group.vpc_endpoints.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

# Allow all outbound traffic
module "allow_outbound_all" {
  source = "../sg-rule"

  security_group_id = aws_security_group.vpc_endpoints.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE VPC ENDPOINTS
# ---------------------------------------------------------------------------------------------------------------------

# Secrets Manager endpoint (for ECS to pull secrets)
resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.enable_secretsmanager ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-secretsmanager"
      Environment = var.environment
    }
  )
}

# ECR API endpoint (for ECS to pull image manifests)
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_ecr ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-ecr-api"
      Environment = var.environment
    }
  )
}

# ECR DKR endpoint (for ECS to pull Docker images)
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_ecr ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-ecr-dkr"
      Environment = var.environment
    }
  )
}

# S3 endpoint (gateway type - FREE, for ECR image layers)
resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3 ? 1 : 0

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-s3"
      Environment = var.environment
    }
  )
}

# CloudWatch Logs endpoint (for ECS to send logs)
resource "aws_vpc_endpoint" "logs" {
  count = var.enable_logs ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-logs"
      Environment = var.environment
    }
  )
}
