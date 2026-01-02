include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/cloudflare-dns?ref=${try(values.version, "main")}"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPENDENCIES - Django service (for ALB DNS name)
# ---------------------------------------------------------------------------------------------------------------------

dependency "django_service" {
  config_path = "../django-fargate-stateful-service"

  mock_outputs = {
    alb_dns_name = "django-alb-1234567890.us-east-1.elb.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["init", "validate", "plan"]
}

# ---------------------------------------------------------------------------------------------------------------------
# INPUTS
# ---------------------------------------------------------------------------------------------------------------------

inputs = {
  # Required inputs
  zone_id     = values.zone_id
  record_name = values.record_name

  # Target is the ALB DNS name from Django service
  target = dependency.django_service.outputs.alb_dns_name

  # DNS configuration
  record_type = try(values.record_type, "CNAME")
  ttl         = try(values.ttl, 1)        # Auto TTL when proxied
  proxied     = try(values.proxied, true) # Enable Cloudflare proxy (DDoS protection, caching, SSL)

  # Optional metadata
  comment     = try(values.comment, "DNS record for Django API - Managed by Terraform")
  environment = try(values.environment, "prod")

  # SSL/TLS settings (optional - usually configured at zone level)
  configure_ssl_settings = try(values.configure_ssl_settings, false)
  ssl_mode               = try(values.ssl_mode, "full")
  always_use_https       = try(values.always_use_https, "on")
  min_tls_version        = try(values.min_tls_version, "1.2")
  http3_enabled          = try(values.http3_enabled, "on")
  brotli_enabled         = try(values.brotli_enabled, "on")

  # Caching rules (optional)
  create_cache_rule      = try(values.create_cache_rule, false)
  cache_rule_priority    = try(values.cache_rule_priority, 1)
  cache_level            = try(values.cache_level, "standard")
  edge_cache_ttl         = try(values.edge_cache_ttl, 7200)                # 2 hours
  browser_cache_ttl      = try(values.browser_cache_ttl, 14400)            # 4 hours
  bypass_cache_on_cookie = try(values.bypass_cache_on_cookie, "session.*") # Don't cache authenticated requests

  # Tags (for documentation)
  tags = try(values.tags, {})
}
