# ---------------------------------------------------------------------------------------------------------------------
# CREATE CLOUDFLARE DNS RECORD
# ---------------------------------------------------------------------------------------------------------------------

resource "cloudflare_record" "dns" {
  zone_id = var.zone_id
  name    = var.record_name
  content = var.target
  type    = var.record_type
  ttl     = var.ttl
  proxied = var.proxied
  comment = var.comment

  # Allow manual changes without terraform interference (for emergency hotfixes)
  allow_overwrite = var.allow_overwrite

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE SSL/TLS SETTINGS (Optional)
# ---------------------------------------------------------------------------------------------------------------------

resource "cloudflare_zone_settings_override" "ssl_settings" {
  count = var.configure_ssl_settings ? 1 : 0

  zone_id = var.zone_id

  settings {
    # SSL/TLS encryption mode
    ssl = var.ssl_mode

    # Always use HTTPS
    always_use_https = var.always_use_https

    # Minimum TLS version
    min_tls_version = var.min_tls_version

    # HTTP/3 (QUIC)
    http3 = var.http3_enabled

    # Brotli compression
    brotli = var.brotli_enabled
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE PAGE RULE FOR CACHING (Optional)
# ---------------------------------------------------------------------------------------------------------------------

resource "cloudflare_page_rule" "cache_rule" {
  count = var.create_cache_rule ? 1 : 0

  zone_id  = var.zone_id
  target   = "${var.record_name}.${data.cloudflare_zone.main.name}/*"
  priority = var.cache_rule_priority

  actions {
    cache_level            = var.cache_level
    edge_cache_ttl         = var.edge_cache_ttl
    browser_cache_ttl      = var.browser_cache_ttl
    cache_on_cookie        = var.cache_on_cookie
    bypass_cache_on_cookie = var.bypass_cache_on_cookie
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DATA SOURCE: FETCH ZONE INFORMATION
# ---------------------------------------------------------------------------------------------------------------------

data "cloudflare_zone" "main" {
  zone_id = var.zone_id
}
