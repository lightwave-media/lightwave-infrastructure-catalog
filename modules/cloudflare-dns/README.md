# Cloudflare DNS Module

This module provisions DNS records in Cloudflare with automated management and optional caching/SSL configuration.

## Features

- **Automated DNS Management**: Create/update DNS records via Terraform
- **Proxy Support**: Enable Cloudflare proxy (orange cloud) for DDoS protection and caching
- **SSL/TLS Configuration**: Automated HTTPS redirect and TLS settings
- **Caching Rules**: Optional page rules for custom caching behavior
- **Multi-environment**: Support for dev/staging/prod domains
- **Zero-downtime Updates**: DNS updates with `create_before_destroy`

## Usage

### Basic CNAME Record (Backend API)

```hcl
module "api_dns" {
  source = "../../modules/cloudflare-dns"

  zone_id     = var.cloudflare_zone_id  # lightwave-media.ltd
  record_name = "api"                    # Creates api.lightwave-media.ltd
  target      = module.django_service.alb_dns_name
  proxied     = true                     # Enable Cloudflare proxy

  environment = "prod"
}
```

### A Record (Direct IP)

```hcl
module "server_dns" {
  source = "../../modules/cloudflare-dns"

  zone_id     = var.cloudflare_zone_id
  record_name = "vpn"
  target      = aws_instance.vpn.public_ip
  record_type = "A"
  proxied     = false  # VPN needs direct connection

  environment = "prod"
}
```

### Apex Domain (Root)

```hcl
module "root_dns" {
  source = "../../modules/cloudflare-dns"

  zone_id     = var.cloudflare_zone_id
  record_name = "@"  # Creates lightwave-media.ltd
  target      = "lightwave-media-site.pages.dev"
  proxied     = true

  environment = "prod"
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| zone_id | Cloudflare Zone ID | string | - | yes |
| record_name | DNS record name | string | - | yes |
| target | Record value (DNS, IP) | string | - | yes |
| record_type | Record type (A, CNAME, etc) | string | CNAME | no |
| ttl | TTL in seconds | number | 1 | no |
| proxied | Enable Cloudflare proxy | bool | true | no |
| configure_ssl_settings | Configure SSL settings | bool | false | no |
| create_cache_rule | Create caching rule | bool | false | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| record_id | DNS record ID |
| fqdn | Fully qualified domain name |
| url | Full HTTPS URL |
| proxied | Whether proxied |
| zone_name | Zone domain name |

## Authentication

Set Cloudflare API token as environment variable:

```bash
export CLOUDFLARE_API_TOKEN="your-api-token"
```

Or pass to Terraform:

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

### Creating API Token

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Select specific zones or all zones
5. Copy token and store in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-api-token \
  --secret-string "your-api-token"
```

## Proxied vs Non-Proxied

| Feature | Proxied (true) | Non-Proxied (false) |
|---------|----------------|---------------------|
| DDoS Protection | ✅ Yes | ❌ No |
| WAF (Firewall) | ✅ Yes | ❌ No |
| Caching | ✅ Yes | ❌ No |
| SSL/TLS | ✅ Yes (auto) | ⚠️ Origin cert required |
| IP Address | Cloudflare IPs | Origin IP exposed |
| Protocols | HTTP/HTTPS only | All protocols |

**When to use non-proxied:**
- SSH/VPN servers
- Mail servers (MX records)
- Custom protocols (non-HTTP)
- Direct IP access required

## SSL/TLS Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `off` | No encryption | Never use |
| `flexible` | CF → Browser encrypted, CF → Origin unencrypted | Testing only |
| `full` | Encrypted both ways, origin cert can be self-signed | Development |
| `strict` | Encrypted both ways, valid CA cert required | **Production** |

**Recommendation**: Always use `strict` in production with valid SSL certificate on origin.

## Example: Production Backend API with SSL

```hcl
# Django API DNS record
module "api_dns_prod" {
  source = "../../modules/cloudflare-dns"

  zone_id     = data.aws_secretsmanager_secret_version.cloudflare_zone_id.secret_string
  record_name = "api"
  target      = module.django_service.alb_dns_name
  record_type = "CNAME"
  proxied     = true
  ttl         = 1  # Auto (proxied)

  # Configure SSL/TLS
  configure_ssl_settings = true
  ssl_mode               = "full"
  always_use_https       = "on"
  min_tls_version        = "1.2"
  http3_enabled          = "on"

  environment = "prod"

  tags = {
    Application = "Django API"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}

output "api_url" {
  value = module.api_dns_prod.url  # https://api.lightwave-media.ltd
}
```

## Example: Multi-Environment Setup

```hcl
locals {
  environments = {
    dev = {
      record_name = "dev-api"
      alb_dns     = module.django_dev.alb_dns_name
    }
    staging = {
      record_name = "staging-api"
      alb_dns     = module.django_staging.alb_dns_name
    }
    prod = {
      record_name = "api"
      alb_dns     = module.django_prod.alb_dns_name
    }
  }
}

module "api_dns" {
  source = "../../modules/cloudflare-dns"

  for_each = local.environments

  zone_id     = var.cloudflare_zone_id
  record_name = each.value.record_name
  target      = each.value.alb_dns
  proxied     = true
  environment = each.key
}

# Outputs:
# dev-api.lightwave-media.ltd     → dev ALB
# staging-api.lightwave-media.ltd → staging ALB
# api.lightwave-media.ltd         → prod ALB
```

## Caching Rules

Enable custom caching for API endpoints:

```hcl
module "api_dns_cached" {
  source = "../../modules/cloudflare-dns"

  zone_id     = var.cloudflare_zone_id
  record_name = "api"
  target      = module.django_service.alb_dns_name
  proxied     = true

  # Custom caching
  create_cache_rule      = true
  cache_level            = "cache_everything"
  edge_cache_ttl         = 3600      # 1 hour
  browser_cache_ttl      = 1800      # 30 minutes
  bypass_cache_on_cookie = "session.*"  # Don't cache authenticated requests
}
```

## Monitoring

Cloudflare provides analytics:
- Requests per second
- Bandwidth usage
- Cache hit ratio
- Security threats blocked
- Response time (p50, p95, p99)

Access via:
- Cloudflare Dashboard → Analytics
- GraphQL API for programmatic access
- Terraform data sources: `cloudflare_zone_dnssec`

## Troubleshooting

### DNS Record Not Resolving
```bash
# Check DNS propagation
dig api.lightwave-media.ltd

# Check Cloudflare nameservers
dig NS lightwave-media.ltd

# Flush local DNS cache (macOS)
sudo dscacheutil -flushcache
```

### SSL Certificate Issues
- Ensure origin server has valid SSL certificate
- Check SSL mode is set to `full` or `strict`
- Verify ALB listener has HTTPS listener with ACM certificate

### Too Many Redirects
- Origin is redirecting HTTP → HTTPS
- Cloudflare is also redirecting
- **Fix**: Set SSL mode to `full` (not `flexible`)

## Cost

Cloudflare DNS is **free** on all plans:
- Unlimited DNS queries
- DNSSEC included
- DDoS protection included
- SSL certificates included

Paid features (not used by this module):
- Load balancing ($5/month + $0.50 per 500K requests)
- Workers ($5/month + $0.50 per 1M requests)
- Argo Smart Routing ($5/month + $0.10 per GB)

## Testing

Run module validation:
```bash
cd examples/tofu/cloudflare-dns
tofu init
tofu plan
```

Run Terratest:
```bash
cd test
export CLOUDFLARE_API_TOKEN="your-token"
go test -v -timeout 15m -run TestCloudflareDNSModule
```

## Security Best Practices

1. **Use API tokens** (not API keys) with minimal permissions
2. **Store tokens in Secrets Manager** (never commit to git)
3. **Enable DNSSEC** on your domain
4. **Use proxied mode** for public-facing services
5. **Enable WAF** for additional security
6. **Set minimum TLS 1.2** or higher

## References

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [SSL/TLS Encryption Modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
