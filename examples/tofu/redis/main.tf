terraform {
  required_version = ">= 1.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# USE THE DEFAULT VPC AND SUBNETS
# To keep this example simple, we use the default VPC and subnets, but in real-world code, you'll want to use a
# custom VPC.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A REDIS ELASTICACHE CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "redis" {
  source = "../../../modules/redis"

  name       = var.name
  node_type  = var.node_type
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # Use minimal settings for testing
  num_cache_clusters         = var.num_cache_nodes
  automatic_failover_enabled = var.automatic_failover
  multi_az_enabled           = var.multi_az

  # Disable auth for simpler testing (enable in production)
  auth_token_enabled         = var.auth_token_enabled
  transit_encryption_enabled = false
  at_rest_encryption_enabled = true

  # Testing: allow deletion without final snapshot
  snapshot_retention_limit = 0

  environment = "test"

  tags = {
    Environment = "test"
    ManagedBy   = "Terratest"
  }
}
