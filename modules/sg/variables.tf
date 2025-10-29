variable "name" {
  description = "Security group name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the security group"
  type        = string
}

variable "description" {
  description = "Security group description"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the security group"
  type        = map(string)
  default     = {}
}
