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

dependency "source_service" {
  config_path = values.source_path

  mock_outputs = {
    service_security_group_id = "sg-mock-source"
  }
}

dependency "dest_service" {
  config_path = values.dest_path

  mock_outputs = {
    db_security_group_id      = "sg-mock-dest-db"
    redis_security_group_id   = "sg-mock-dest-redis"
  }
}

inputs = {
  # Destination security group (receives the ingress rule)
  # Use either db_security_group_id or redis_security_group_id from dest outputs
  security_group_id = try(
    dependency.dest_service.outputs.db_security_group_id,
    dependency.dest_service.outputs.redis_security_group_id
  )

  # Source security group (allowed to connect)
  source_security_group_id = dependency.source_service.outputs.service_security_group_id

  # Port configuration
  from_port = try(values.port, 5432)  # Default to PostgreSQL port, configurable
  to_port   = try(values.port, 5432)
  protocol  = try(values.protocol, "tcp")

  # Rule type
  type = "ingress"
}
