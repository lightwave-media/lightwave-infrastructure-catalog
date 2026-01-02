include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/cloudflare-dns"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES - S3 Bucket (for website endpoint)
# ---------------------------------------------------------------------------------------------------------------------

dependency "s3_bucket" {
  config_path = values.s3_bucket_path

  mock_outputs = {
    website_endpoint = "lightwave-cdn-prod.s3-website-us-east-1.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS - Cloudflare DNS for S3 CDN
# ---------------------------------------------------------------------------------------------------------------------
# Points a subdomain to an S3 bucket's website endpoint.
# Cloudflare proxies the request for caching, DDoS protection, and SSL.
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Required inputs
  zone_id     = values.zone_id
  record_name = values.record_name

  # Target is the S3 website endpoint
  target = dependency.s3_bucket.outputs.website_endpoint

  # DNS configuration
  record_type = "CNAME"
  ttl         = try(values.ttl, 1)        # Auto TTL when proxied
  proxied     = try(values.proxied, true) # Enable Cloudflare proxy

  # Optional metadata
  comment     = try(values.comment, "CDN DNS record for S3 bucket - Managed by Terraform")
  environment = try(values.environment, "prod")

  # SSL/TLS settings
  configure_ssl_settings = try(values.configure_ssl_settings, false)
  ssl_mode               = try(values.ssl_mode, "full")
  always_use_https       = try(values.always_use_https, "on")
  min_tls_version        = try(values.min_tls_version, "1.2")
  http3_enabled          = try(values.http3_enabled, "on")
  brotli_enabled         = try(values.brotli_enabled, "on")

  # Caching rules (highly recommended for CDN)
  create_cache_rule      = try(values.create_cache_rule, true)
  cache_rule_priority    = try(values.cache_rule_priority, 1)
  cache_level            = try(values.cache_level, "cache_everything")
  edge_cache_ttl         = try(values.edge_cache_ttl, 604800)  # 7 days default
  browser_cache_ttl      = try(values.browser_cache_ttl, 2592000) # 30 days default
  bypass_cache_on_cookie = null # No cookies on CDN

  # Tags (for documentation)
  tags = try(values.tags, {})
}
