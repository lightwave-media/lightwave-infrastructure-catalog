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
# S3 CDN BUCKET EXAMPLE
# ---------------------------------------------------------------------------------------------------------------------
# This example creates an S3 bucket configured for CDN use with:
# - Public read access (HTTPS only)
# - Static website hosting
# - CORS configuration
# - Server-side encryption
# ---------------------------------------------------------------------------------------------------------------------

module "s3_cdn_bucket" {
  source = "../../../modules/s3-bucket"

  name = var.name

  # CDN configuration
  block_public_access    = false
  enable_public_read     = true
  enable_website_hosting = true
  enable_cors            = true

  # Restrict CORS to test origins
  cors_allowed_origins = var.cors_allowed_origins

  # CDN assets don't need versioning (use filename versioning instead)
  enable_versioning = false

  # Do NOT copy this into product code. We only set this param to true here so that the automated tests can clean up.
  force_destroy = true

  tags = {
    Environment = "test"
    Purpose     = "cdn-test"
  }
}
