# ---------------------------------------------------------------------------------------------------------------------
# CREATE DB SUBNET GROUP
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_subnet_group" "postgresql" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-subnet-group"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A POSTGRESQL DATABASE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_instance" "postgresql" {
  engine         = "postgres"
  engine_version = var.engine_version

  db_name  = var.name
  username = var.master_username
  password = var.master_password

  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type

  # Production features
  multi_az                        = var.multi_az
  backup_retention_period         = var.backup_retention_period
  backup_window                   = var.backup_window
  maintenance_window              = var.maintenance_window
  storage_encrypted               = var.storage_encrypted
  kms_key_id                      = var.kms_key_id
  max_allocated_storage           = var.max_allocated_storage
  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  # Performance
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period

  # Deletion protection
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Networking
  db_subnet_group_name = aws_db_subnet_group.postgresql.name

  # Security
  vpc_security_group_ids = [aws_security_group.db.id]

  # Parameter group for Django-optimized settings
  parameter_group_name = var.parameter_group_name != null ? var.parameter_group_name : aws_db_parameter_group.postgresql[0].name

  tags = merge(
    var.tags,
    {
      Name        = var.name
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A PARAMETER GROUP FOR POSTGRESQL (Django-optimized)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_parameter_group" "postgresql" {
  count = var.parameter_group_name == null ? 1 : 0

  name   = "${var.name}-pg"
  family = var.parameter_group_family

  # Django-optimized PostgreSQL parameters
  parameter {
    name  = "shared_buffers"
    value = var.shared_buffers
  }

  parameter {
    name  = "max_connections"
    value = var.max_connections
  }

  parameter {
    name  = "work_mem"
    value = var.work_mem
  }

  parameter {
    name  = "maintenance_work_mem"
    value = var.maintenance_work_mem
  }

  parameter {
    name  = "effective_cache_size"
    value = var.effective_cache_size
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1" # Optimized for SSD storage
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries slower than 1 second
  }

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-pg"
      Environment = var.environment
    }
  )
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP FOR THE POSTGRESQL DATABASE
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "Security group for ${var.name} PostgreSQL database"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.name}-db"
      Environment = var.environment
    }
  )
}

module "allow_outbound_all" {
  source = "../sg-rule"

  security_group_id = aws_security_group.db.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
