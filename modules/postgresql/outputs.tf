output "endpoint" {
  description = "The connection endpoint for the database (hostname:port)"
  value       = aws_db_instance.postgresql.endpoint
}

output "address" {
  description = "The hostname of the database"
  value       = aws_db_instance.postgresql.address
}

output "port" {
  description = "The port the database is listening on"
  value       = aws_db_instance.postgresql.port
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.postgresql.db_name
}

output "username" {
  description = "The master username for the database"
  value       = aws_db_instance.postgresql.username
  sensitive   = true
}

output "arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.postgresql.arn
}

output "db_security_group_id" {
  description = "The ID of the security group attached to the database"
  value       = aws_security_group.db.id
}

output "resource_id" {
  description = "The resource ID of the DB instance"
  value       = aws_db_instance.postgresql.resource_id
}

output "connection_string" {
  description = "PostgreSQL connection string (DATABASE_URL format for Django)"
  value       = "postgresql://${aws_db_instance.postgresql.username}:${var.master_password}@${aws_db_instance.postgresql.address}:${aws_db_instance.postgresql.port}/${aws_db_instance.postgresql.db_name}"
  sensitive   = true
}
