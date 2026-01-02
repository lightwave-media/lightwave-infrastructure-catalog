output "bucket_name" {
  description = "The name of the bucket"
  value       = module.s3_cdn_bucket.name
}

output "bucket_arn" {
  description = "The ARN of the bucket"
  value       = module.s3_cdn_bucket.arn
}

output "website_endpoint" {
  description = "The website endpoint for the bucket"
  value       = module.s3_cdn_bucket.website_endpoint
}

output "website_domain" {
  description = "The website domain for the bucket"
  value       = module.s3_cdn_bucket.website_domain
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the bucket"
  value       = module.s3_cdn_bucket.bucket_regional_domain_name
}
