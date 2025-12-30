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
# DEPLOY A POSTGRESQL RDS INSTANCE
# ---------------------------------------------------------------------------------------------------------------------

module "postgresql" {
  source = "../../../modules/postgresql"

  name              = var.name
  db_name           = var.db_name
  master_username   = var.master_username
  master_password   = var.master_password
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # Use minimal settings for testing
  multi_az                     = var.multi_az
  backup_retention_period      = 0
  deletion_protection          = false
  skip_final_snapshot          = true
  performance_insights_enabled = false

  environment = "test"

  tags = {
    Environment = "test"
    ManagedBy   = "Terratest"
  }
}
