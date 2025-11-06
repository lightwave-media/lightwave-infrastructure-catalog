# Cloudflare DNS Unit

This unit creates a DNS record in Cloudflare pointing to the Django service's Application Load Balancer.

## Usage

### Production Configuration

```yaml
# config/cloudflare-dns-prod.yaml
zone_id: "your-cloudflare-zone-id"  # From environment variable or Secrets Manager
record_name: "api"                   # Creates api.lightwave-media.ltd
proxied: true                        # Enable Cloudflare proxy (DDoS, WAF, SSL)
environment: "prod"

tags:
  Application: "Django API"
  Environment: "production"
```

### Development Configuration

```yaml
# config/cloudflare-dns-dev.yaml
zone_id: "your-cloudflare-zone-id"
record_name: "dev-api"  # Creates dev-api.lightwave-media.ltd
proxied: true
environment: "dev"

tags:
  Application: "Django API"
  Environment: "development"
```

## Prerequisites

### 1. Cloudflare API Token

Create API token with "Edit zone DNS" permissions:

```bash
# Store in Secrets Manager
aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-api-token \
  --secret-string "your-cloudflare-api-token"

# Load token for Terraform
export CLOUDFLARE_API_TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id /lightwave/prod/cloudflare-api-token \
  --query SecretString --output text)
```

### 2. Cloudflare Zone ID

Get your zone ID:

```bash
# Via Cloudflare dashboard
# Domain → Overview → Zone ID (right sidebar)

# Or via API
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json"

# Store in Secrets Manager
aws secretsmanager create-secret \
  --name /lightwave/prod/cloudflare-zone-id \
  --secret-string "your-zone-id"
```

## Deployment

```bash
# Set Cloudflare credentials
export CLOUDFLARE_API_TOKEN="your-token"

# Deploy DNS record
cd units/cloudflare-dns
terragrunt apply

# Get FQDN
terragrunt output fqdn
# Output: api.lightwave-media.ltd

# Get full URL
terragrunt output url
# Output: https://api.lightwave-media.ltd
```

## What Gets Created

1. **CNAME Record**: Points `api.lightwave-media.ltd` → ALB DNS name
2. **Cloudflare Proxy**: Enabled (orange cloud icon in dashboard)
3. **Automatic SSL**: Cloudflare SSL certificate
4. **DDoS Protection**: Enabled automatically
5. **WAF**: Web Application Firewall available

## Verification

```bash
# Check DNS resolution
dig api.lightwave-media.ltd

# Check HTTPS
curl -I https://api.lightwave-media.ltd/health/live/

# Expected output:
# HTTP/2 200
# server: cloudflare
# ...
```

## Integration with Django Stack

This unit depends on the Django service unit and automatically uses its ALB DNS name as the target.

```hcl
# Dependency chain:
# postgresql → django-fargate-stateful-service → cloudflare-dns
# redis      ↗
```

## Outputs

- `fqdn` - Full domain name (e.g. api.lightwave-media.ltd)
- `url` - Full HTTPS URL
- `record_id` - Cloudflare record ID
- `proxied` - Whether proxied (should be true)

## Multi-Environment Setup

```yaml
# Production
record_name: "api"
# Creates: api.lightwave-media.ltd

# Staging
record_name: "staging-api"
# Creates: staging-api.lightwave-media.ltd

# Development
record_name: "dev-api"
# Creates: dev-api.lightwave-media.ltd
```

## SSL/TLS Configuration

Cloudflare provides automatic SSL certificates. For production:

1. **SSL Mode**: Set to "Full" or "Full (strict)"
2. **Min TLS Version**: 1.2 or higher
3. **Always Use HTTPS**: Enabled
4. **HTTP/3**: Enabled for performance

These can be configured via the unit inputs:

```yaml
configure_ssl_settings: true
ssl_mode: "full"
min_tls_version: "1.2"
always_use_https: "on"
http3_enabled: "on"
```

## Caching Configuration

For API endpoints, you typically want to bypass cache for authenticated requests:

```yaml
create_cache_rule: true
cache_level: "standard"
edge_cache_ttl: 7200  # 2 hours
bypass_cache_on_cookie: "session.*"  # Don't cache if session cookie present
```

## Troubleshooting

### DNS Not Resolving
```bash
# Check if record was created
dig api.lightwave-media.ltd

# Check Cloudflare nameservers
dig NS lightwave-media.ltd

# If not resolving, check:
# 1. Domain nameservers point to Cloudflare
# 2. Terraform apply succeeded
# 3. Cloudflare dashboard shows record
```

### SSL Certificate Errors
```bash
# Check SSL mode
curl -I https://api.lightwave-media.ltd

# Ensure:
# 1. ALB has HTTPS listener with ACM certificate
# 2. Cloudflare SSL mode is "Full" (not "Flexible")
# 3. Origin server (ALB) has valid SSL certificate
```

### 520/521/522 Errors (Cloudflare)
- **520**: Web server returned unknown error
- **521**: Web server is down
- **522**: Connection timed out

**Solutions**:
1. Check Django service is healthy
2. Verify security groups allow Cloudflare IPs
3. Check ALB target health in AWS Console

## Cost

Cloudflare DNS is **free** on all plans:
- Unlimited DNS queries
- DDoS protection included
- SSL certificates included
- WAF available on paid plans

## Security Best Practices

1. **Use API tokens** (not global API keys)
2. **Store tokens in Secrets Manager**
3. **Enable proxy** for DDoS protection
4. **Use Full SSL mode** in production
5. **Enable minimum TLS 1.2**
6. **Monitor Cloudflare Security Events**

## References

- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)
- [Cloudflare SSL Modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)
- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
