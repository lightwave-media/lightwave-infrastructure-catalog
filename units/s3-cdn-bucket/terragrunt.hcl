include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/s3-bucket?ref=${try(values.version, "main")}"
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS - S3 CDN Bucket
# ---------------------------------------------------------------------------------------------------------------------
# This unit creates an S3 bucket configured for CDN use:
# - Public read access (via bucket policy)
# - Static website hosting enabled
# - CORS configured for cross-domain requests
# - No versioning (CDN assets are immutable, versioned via filenames)
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  name = values.name

  # CDN buckets need public access
  block_public_access = false
  enable_public_read  = true

  # Enable static website hosting (required for Cloudflare to proxy)
  enable_website_hosting = true
  website_index_document = try(values.website_index_document, "index.html")
  website_error_document = try(values.website_error_document, "404.html")

  # CORS for cross-domain asset requests
  # SECURITY: cors_allowed_origins is REQUIRED - no default to prevent accidental exposure
  # Example: ["https://example.com", "https://www.example.com"]
  enable_cors          = true
  cors_allowed_origins = values.cors_allowed_origins
  cors_allowed_methods = try(values.cors_allowed_methods, ["GET", "HEAD"])
  cors_allowed_headers = try(values.cors_allowed_headers, ["*"])
  cors_max_age_seconds = try(values.cors_max_age_seconds, 86400) # 24 hours

  # CDN assets are immutable (versioned via filenames like main-abc123.js)
  enable_versioning = try(values.enable_versioning, false)

  # Don't destroy bucket contents on terraform destroy
  force_destroy = try(values.force_destroy, false)

  # Tags
  tags = merge(
    try(values.tags, {}),
    {
      Environment = try(values.environment, "prod")
      Purpose     = "cdn"
      ManagedBy   = "terraform"
    }
  )
}
