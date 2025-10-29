# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED VARIABLES
# ---------------------------------------------------------------------------------------------------------------------

variable "zone_id" {
  description = "The Cloudflare Zone ID where the DNS record will be created"
  type        = string
}

variable "record_name" {
  description = "The name of the DNS record (e.g. 'api' for api.example.com, or '@' for example.com)"
  type        = string
}

variable "target" {
  description = "The value of the DNS record (e.g. ALB DNS name, IP address, or another domain)"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - DNS Record Configuration
# ---------------------------------------------------------------------------------------------------------------------

variable "record_type" {
  description = "The type of DNS record. Common values: A, AAAA, CNAME, TXT, MX"
  type        = string
  default     = "CNAME"

  validation {
    condition     = contains(["A", "AAAA", "CNAME", "TXT", "MX", "NS", "SRV", "CAA"], var.record_type)
    error_message = "record_type must be one of: A, AAAA, CNAME, TXT, MX, NS, SRV, CAA"
  }
}

variable "ttl" {
  description = "TTL of the DNS record in seconds. Use 1 for automatic (when proxied = true). Min: 60, Max: 86400"
  type        = number
  default     = 1
}

variable "proxied" {
  description = "Whether the record should be proxied through Cloudflare (orange cloud). Enables DDoS protection, WAF, caching"
  type        = bool
  default     = true
}

variable "comment" {
  description = "Comments or notes about the DNS record"
  type        = string
  default     = null
}

variable "allow_overwrite" {
  description = "Allow Terraform to overwrite manually created records with same name"
  type        = bool
  default     = false
}

variable "environment" {
  description = "The environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - SSL/TLS Settings
# ---------------------------------------------------------------------------------------------------------------------

variable "configure_ssl_settings" {
  description = "Whether to configure SSL/TLS settings for the zone. Set to false if already configured elsewhere."
  type        = bool
  default     = false
}

variable "ssl_mode" {
  description = "SSL/TLS encryption mode. Options: off, flexible, full, full (strict)"
  type        = string
  default     = "full"

  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "ssl_mode must be one of: off, flexible, full, strict"
  }
}

variable "always_use_https" {
  description = "Automatically redirect HTTP requests to HTTPS"
  type        = string
  default     = "on"
}

variable "min_tls_version" {
  description = "Minimum TLS version supported. Options: 1.0, 1.1, 1.2, 1.3"
  type        = string
  default     = "1.2"
}

variable "http3_enabled" {
  description = "Enable HTTP/3 (QUIC) for improved performance"
  type        = string
  default     = "on"
}

variable "brotli_enabled" {
  description = "Enable Brotli compression"
  type        = string
  default     = "on"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Caching Rules
# ---------------------------------------------------------------------------------------------------------------------

variable "create_cache_rule" {
  description = "Whether to create a page rule for caching configuration"
  type        = bool
  default     = false
}

variable "cache_rule_priority" {
  description = "Priority of the page rule (lower number = higher priority)"
  type        = number
  default     = 1
}

variable "cache_level" {
  description = "Cache level. Options: bypass, basic, simplified, aggressive, cache_everything"
  type        = string
  default     = "standard"
}

variable "edge_cache_ttl" {
  description = "Edge cache TTL in seconds. How long Cloudflare caches resources."
  type        = number
  default     = 7200 # 2 hours
}

variable "browser_cache_ttl" {
  description = "Browser cache TTL in seconds. How long browsers cache resources."
  type        = number
  default     = 14400 # 4 hours
}

variable "cache_on_cookie" {
  description = "Cookie name to cache on (e.g. 'session_id'). Leave null to disable."
  type        = string
  default     = null
}

variable "bypass_cache_on_cookie" {
  description = "Cookie name regex to bypass cache (e.g. 'session.*'). Leave null to disable."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL VARIABLES - Tags
# ---------------------------------------------------------------------------------------------------------------------

variable "tags" {
  description = "A map of tags to apply to resources (Note: Cloudflare DNS records don't support tags, used for documentation)"
  type        = map(string)
  default     = {}
}
