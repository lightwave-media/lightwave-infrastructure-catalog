output "endpoint" {
  description = "The connection endpoint (hostname:port)"
  value       = module.postgresql.endpoint
}

output "address" {
  description = "The hostname of the database"
  value       = module.postgresql.address
}

output "port" {
  description = "The port the database is listening on"
  value       = module.postgresql.port
}

output "db_name" {
  description = "The name of the database"
  value       = module.postgresql.db_name
}

output "arn" {
  description = "The ARN of the RDS instance"
  value       = module.postgresql.arn
}

output "db_security_group_id" {
  description = "The ID of the security group"
  value       = module.postgresql.db_security_group_id
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = module.postgresql.connection_string
  sensitive   = true
}
