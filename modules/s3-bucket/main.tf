# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE S3 BUCKET
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "bucket" {
  bucket        = var.name
  force_destroy = var.force_destroy

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# ENABLE VERSIONING
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bucket.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SERVER-SIDE ENCRYPTION (always enabled)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BLOCK PUBLIC ACCESS (disable for CDN buckets)
# ---------------------------------------------------------------------------------------------------------------------
# Always create this resource with explicit settings to avoid relying on AWS defaults

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

# ---------------------------------------------------------------------------------------------------------------------
# STATIC WEBSITE HOSTING (for CDN buckets)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_website_configuration" "website" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_error_document
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# BUCKET POLICY FOR PUBLIC READ (CDN buckets)
# ---------------------------------------------------------------------------------------------------------------------
# Note: Requires block_public_access = false to allow public bucket policies
#
# IMPORTANT: S3 website endpoints only support HTTP, not HTTPS directly.
# The SecureTransport condition ensures requests to the S3 API use HTTPS.
# For CDN use, Cloudflare terminates HTTPS and proxies to S3 over HTTP.
# Architecture: User --HTTPS--> Cloudflare --HTTP--> S3 Website Endpoint
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "public_read" {
  count  = var.enable_public_read ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  # Wait for public access block to be configured before applying policy
  depends_on = [aws_s3_bucket_public_access_block.public_access]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.bucket.arn}/*"
      }
    ]
  })

  lifecycle {
    precondition {
      condition     = !var.block_public_access
      error_message = "enable_public_read requires block_public_access = false"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CORS CONFIGURATION (for CDN buckets serving assets to multiple domains)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_cors_configuration" "cors" {
  count  = var.enable_cors ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  cors_rule {
    allowed_headers = var.cors_allowed_headers
    allowed_methods = var.cors_allowed_methods
    allowed_origins = var.cors_allowed_origins
    expose_headers  = var.cors_expose_headers
    max_age_seconds = var.cors_max_age_seconds
  }
}
