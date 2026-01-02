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
# BLOCK PUBLIC ACCESS (disable for CDN buckets)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "public_access" {
  count                   = var.block_public_access ? 1 : 0
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
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

resource "aws_s3_bucket_policy" "public_read" {
  count  = var.enable_public_read ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

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

  depends_on = [aws_s3_bucket_public_access_block.public_access]
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
