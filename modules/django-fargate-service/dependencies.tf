# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCES
# These data sources are used to fetch information about the AWS environment
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "public" {
  for_each = toset(var.public_subnet_ids)
  id       = each.value
}

data "aws_region" "current" {}
