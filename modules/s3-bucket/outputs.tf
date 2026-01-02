output "name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.bucket.bucket
}

output "arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the bucket (for Cloudflare CNAME)"
  value       = aws_s3_bucket.bucket.bucket_regional_domain_name
}

output "website_endpoint" {
  description = "The website endpoint of the bucket (if website hosting is enabled)"
  value       = try(aws_s3_bucket_website_configuration.website[0].website_endpoint, null)
}

output "website_domain" {
  description = "The domain of the website endpoint (if website hosting is enabled)"
  value       = try(aws_s3_bucket_website_configuration.website[0].website_domain, null)
}
