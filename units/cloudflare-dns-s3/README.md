# Cloudflare DNS S3 Unit

Points a Cloudflare DNS record to an S3 bucket's website endpoint for CDN delivery.

## Features

- CNAME record pointing to S3 website endpoint
- Cloudflare proxy enabled (orange cloud) for:
  - Edge caching
  - DDoS protection
  - SSL termination
  - Brotli compression
- Configurable cache rules for static assets

## Prerequisites

1. **S3 Bucket**: Must have `enable_website_hosting = true`
2. **Cloudflare Zone**: Zone ID for your domain
3. **Cloudflare API Token**: With DNS edit permissions

## Usage

```hcl
unit "cdn_dns" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//units/cloudflare-dns-s3?ref=main"
  path   = "cdn-dns"

  values = {
    zone_id        = "your-cloudflare-zone-id"
    record_name    = "cdn"  # Creates cdn.yourdomain.com
    s3_bucket_path = "../cdn-bucket"  # Path to s3-cdn-bucket unit
    environment    = "prod"
  }
}
```

## Complete CDN Stack Example

```hcl
# terragrunt.stack.hcl
locals {
  environment = "prod"
}

unit "s3_cdn" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//units/s3-cdn-bucket?ref=main"
  path   = "s3-bucket"

  values = {
    name        = "my-cdn-${local.environment}"
    environment = local.environment
    cors_allowed_origins = ["https://example.com"]
  }
}

unit "cloudflare_dns" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//units/cloudflare-dns-s3?ref=main"
  path   = "cloudflare-dns"

  values = {
    zone_id        = "your-zone-id"
    record_name    = "cdn"
    s3_bucket_path = "../s3-bucket"
    environment    = local.environment
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| zone_id | Cloudflare Zone ID | string | - | yes |
| record_name | DNS record name (e.g., "cdn" for cdn.domain.com) | string | - | yes |
| s3_bucket_path | Terragrunt path to S3 bucket unit | string | - | yes |
| environment | Environment tag | string | "prod" | no |
| proxied | Enable Cloudflare proxy (orange cloud) | bool | true | no |
| ttl | DNS TTL (1 = auto when proxied) | number | 1 | no |
| comment | DNS record comment | string | "CDN DNS record..." | no |
| create_cache_rule | Create Cloudflare cache rule | bool | true | no |
| cache_rule_priority | Cache rule priority | number | 1 | no |
| cache_level | Cache level (cache_everything recommended) | string | "cache_everything" | no |
| edge_cache_ttl | Edge cache TTL in seconds | number | 604800 (7 days) | no |
| browser_cache_ttl | Browser cache TTL in seconds | number | 2592000 (30 days) | no |

## Outputs

Inherits outputs from the `cloudflare-dns` module:

| Name | Description |
|------|-------------|
| record_id | The Cloudflare DNS record ID |
| fqdn | The fully qualified domain name (e.g., cdn.example.com) |

## Architecture

```
                    ┌─────────────────────────────────────────┐
                    │           Cloudflare Edge               │
User ──HTTPS──►     │  ┌─────────────────────────────────┐   │
                    │  │  cdn.example.com                │   │
                    │  │  - SSL termination              │   │
                    │  │  - Edge caching (7 days)        │   │
                    │  │  - Brotli compression           │   │
                    │  │  - DDoS protection              │   │
                    │  └─────────────┬───────────────────┘   │
                    └────────────────│────────────────────────┘
                                     │ CNAME
                                     ▼
                    ┌─────────────────────────────────────────┐
                    │              AWS S3                     │
                    │  bucket.s3-website-region.amazonaws.com │
                    │  - Website hosting                      │
                    │  - Public read (HTTPS only)             │
                    │  - CORS headers                         │
                    └─────────────────────────────────────────┘
```

## Cache Configuration

Default cache settings are optimized for static CDN assets:

| Setting | Default | Description |
|---------|---------|-------------|
| Edge Cache TTL | 7 days | How long Cloudflare caches at edge |
| Browser Cache TTL | 30 days | Cache-Control header for browsers |
| Cache Level | cache_everything | Cache all static assets |

### Cache Invalidation

Since assets use versioned filenames (e.g., `main-abc123.js`), cache invalidation is rarely needed. If required:

```bash
# Purge specific URL
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  --data '{"files":["https://cdn.example.com/static/main.js"]}'

# Purge everything (use sparingly)
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

## Troubleshooting

### DNS not resolving

1. Check Cloudflare Zone ID is correct
2. Verify API token has DNS edit permissions
3. Wait for DNS propagation (up to 5 minutes)

### 403 Forbidden from S3

1. Ensure S3 bucket has `enable_website_hosting = true`
2. Verify `block_public_access = false` on the bucket
3. Check bucket policy allows public read

### Assets not caching

1. Verify Cloudflare proxy is enabled (orange cloud)
2. Check cache rule is created
3. Inspect response headers for `CF-Cache-Status`

## Related Units

- [s3-cdn-bucket](../s3-cdn-bucket/) - Creates the S3 bucket for CDN
- [cloudflare-dns](../cloudflare-dns/) - Generic Cloudflare DNS unit
