resource "aws_security_group" "sg" {
  name        = var.name
  vpc_id      = var.vpc_id
  description = coalesce(var.description, "Security group for ${var.name}")

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}
