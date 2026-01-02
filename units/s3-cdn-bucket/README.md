# S3 CDN Bucket Unit

Creates an S3 bucket configured for CDN use with Cloudflare or other edge proxies.

## Features

- Public read access via bucket policy (HTTPS required)
- Static website hosting enabled
- CORS configured for cross-domain requests
- Server-side encryption (AES256)
- No versioning by default (CDN assets are immutable, versioned via filenames)

## Usage

```hcl
unit "cdn_bucket" {
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//units/s3-cdn-bucket?ref=main"
  path   = "cdn-bucket"

  values = {
    name        = "my-cdn-bucket"
    environment = "prod"

    # REQUIRED: Specify allowed origins for CORS
    cors_allowed_origins = [
      "https://example.com",
      "https://www.example.com",
    ]
  }
}
```

## Security Warnings

### Public Bucket

This unit creates a **publicly accessible** S3 bucket. Only use for:
- Static assets (CSS, JS, images, fonts)
- Public media files
- Non-sensitive content

**Never store** in this bucket:
- User data or PII
- API keys or secrets
- Configuration files
- Database backups

### CORS Configuration

`cors_allowed_origins` is **required** - you must explicitly specify which domains can access your CDN assets. This prevents accidental exposure to all origins.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | The name of the S3 bucket | string | - | yes |
| cors_allowed_origins | Allowed origins for CORS (security requirement) | list(string) | - | yes |
| environment | Environment tag (prod, staging, dev) | string | "prod" | no |
| cors_allowed_methods | Allowed HTTP methods | list(string) | ["GET", "HEAD"] | no |
| cors_allowed_headers | Allowed headers | list(string) | ["*"] | no |
| cors_max_age_seconds | CORS preflight cache duration | number | 86400 | no |
| website_index_document | Index document for website | string | "index.html" | no |
| website_error_document | Error document for website | string | "404.html" | no |
| enable_versioning | Enable S3 versioning | bool | false | no |
| force_destroy | Delete contents on destroy | bool | false | no |
| tags | Additional tags | map(string) | {} | no |

## Outputs

Inherits all outputs from the `s3-bucket` module:

| Name | Description |
|------|-------------|
| name | The bucket name |
| arn | The bucket ARN |
| website_endpoint | The website endpoint (for Cloudflare CNAME) |
| website_domain | The website domain |
| bucket_regional_domain_name | Regional domain name |

## Architecture

**Important**: S3 website endpoints only support HTTP, not HTTPS. Cloudflare handles HTTPS termination.

```
User Request (HTTPS)
    │
    ▼
Cloudflare (Edge Cache)
    │ - SSL/TLS termination
    │ - Edge caching (7 days default)
    │ - Brotli compression
    │ - DDoS protection
    │
    │ CNAME: cdn.example.com → bucket.s3-website-region.amazonaws.com
    │ (HTTP connection to origin)
    ▼
S3 Bucket (Origin)
    │ - Website hosting enabled
    │ - Public read policy
    │ - CORS headers
    ▼
Static Asset
```

This architecture ensures end-users always connect via HTTPS while S3 serves content efficiently.

## Cache Strategy

For optimal performance with Cloudflare:

1. **Use versioned filenames**: `main-abc123.js` instead of `main.js`
2. **Set long cache TTLs**: Cloudflare caches for 7 days, browser for 30 days
3. **No cache invalidation needed**: New versions get new filenames

## Uploading Assets

```bash
# Sync static files with cache headers
aws s3 sync ./dist s3://my-cdn-bucket/static/ \
  --cache-control "max-age=31536000,public" \
  --delete

# Sync media files with shorter cache
aws s3 sync ./media s3://my-cdn-bucket/media/ \
  --cache-control "max-age=86400,public"
```

## Related Units

- [cloudflare-dns-s3](../cloudflare-dns-s3/) - Points Cloudflare DNS to this bucket
