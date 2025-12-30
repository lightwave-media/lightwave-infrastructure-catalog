include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  // NOTE: Take note that this source here uses
  // a Git URL instead of a local path.
  //
  // This is because units and stacks are generated
  // as shallow directories when consumed.
  //
  // Assume that a user consuming this unit will exclusively have access
  // to the directory this file is in, and nothing else in this repository.
  source = "git::https://github.com/lightwave-media/lightwave-infrastructure-catalog.git//modules/sg-rule?ref=${try(values.version, "main")}"
}

# =============================================================================
# VPC Endpoint Access Rule
# =============================================================================
# This unit creates an ingress rule on an EXISTING VPC endpoint security group
# to allow traffic from an ECS service (or other source SG).
#
# Use this when VPC endpoints already exist and you need to whitelist a new
# ECS service to access them.
#
# Required values:
#   - vpc_endpoint_sg_id: The security group ID of the VPC endpoints
#   - source_service_path: Path to the ECS service unit to get its SG ID
#
# Optional values:
#   - port: Port to allow (default: 443 for HTTPS endpoints)
#   - protocol: Protocol (default: tcp)
#   - description: Rule description
# =============================================================================

dependency "source_service" {
  config_path = values.source_service_path

  mock_outputs = {
    service_security_group_id = "sg-mock-source"
    ecs_security_group_id     = "sg-mock-source"
  }
}

inputs = {
  # Destination: VPC endpoint security group (receives the ingress rule)
  security_group_id = values.vpc_endpoint_sg_id

  # Source: ECS service security group (allowed to connect)
  # Try multiple output names for compatibility with different service modules
  source_security_group_id = try(
    dependency.source_service.outputs.service_security_group_id,
    dependency.source_service.outputs.ecs_security_group_id,
    dependency.source_service.outputs.security_group_id
  )

  # Port configuration - default to HTTPS (443) for VPC endpoints
  from_port = try(values.port, 443)
  to_port   = try(values.port, 443)
  protocol  = try(values.protocol, "tcp")

  # Rule type
  type = "ingress"
}
