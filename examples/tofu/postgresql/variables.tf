variable "name" {
  description = "The name of the DB instance"
  type        = string
}

variable "db_name" {
  description = "The name of the database to create"
  type        = string
  default     = null
}

variable "master_username" {
  description = "The username for the master user"
  type        = string
  sensitive   = true
}

variable "master_password" {
  description = "The password for the master user"
  type        = string
  sensitive   = true
}

variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "instance_class" {
  description = "The instance class of the DB"
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "The amount of storage to allocate (GB)"
  type        = number
  default     = 20
}

variable "multi_az" {
  description = "Whether Multi-AZ is enabled"
  type        = bool
  default     = false
}
