include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/vpc-endpoints?ref=${try(values.version, "main")}"
}

inputs = {
  # Required inputs
  name                     = values.name
  vpc_id                   = values.vpc_id
  vpc_cidr                 = values.vpc_cidr
  private_subnet_ids       = values.private_subnet_ids
  private_route_table_ids  = values.private_route_table_ids

  # Optional inputs with production defaults
  aws_region            = try(values.aws_region, "us-east-1")
  environment           = try(values.environment, "prod")
  enable_secretsmanager = try(values.enable_secretsmanager, true)
  enable_ecr            = try(values.enable_ecr, true)
  enable_s3             = try(values.enable_s3, true)
  enable_logs           = try(values.enable_logs, true)

  # Tags
  tags = try(values.tags, {})
}
