output "record_id" {
  description = "The ID of the DNS record"
  value       = cloudflare_record.dns.id
}

output "record_name" {
  description = "The name of the DNS record"
  value       = cloudflare_record.dns.name
}

output "fqdn" {
  description = "The fully qualified domain name (FQDN) of the DNS record"
  value       = cloudflare_record.dns.hostname
}

output "record_type" {
  description = "The type of DNS record"
  value       = cloudflare_record.dns.type
}

output "content" {
  description = "The content/target of the DNS record"
  value       = cloudflare_record.dns.content
}

output "proxied" {
  description = "Whether the record is proxied through Cloudflare"
  value       = cloudflare_record.dns.proxied
}

output "proxiable" {
  description = "Whether the record can be proxied"
  value       = cloudflare_record.dns.proxiable
}

output "zone_name" {
  description = "The domain name of the zone"
  value       = data.cloudflare_zone.main.name
}

output "url" {
  description = "The full URL of the service (https://)"
  value       = "https://${cloudflare_record.dns.hostname}"
}
