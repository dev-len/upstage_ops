locals {
  use_existing_security_groups = (
    var.existing_server_security_group_id != null &&
    var.existing_worker_shared_security_group_id != null
  )
}

check "security_group_override_pair" {
  assert {
    condition = (
      (var.existing_server_security_group_id == null && var.existing_worker_shared_security_group_id == null) ||
      (var.existing_server_security_group_id != null && var.existing_worker_shared_security_group_id != null)
    )
    error_message = "existing_server_security_group_id and existing_worker_shared_security_group_id must be set together or both left null."
  }
}

module "security_groups" {
  count  = local.use_existing_security_groups ? 0 : 1
  source = "../../modules/security-groups"

  name_prefix = var.name_prefix
  vpc_id      = var.vpc_id
  admin_cidr  = var.admin_cidr
}

module "k3s_nodes" {
  source = "../../modules/ec2-k3s-nodes"

  name_prefix                     = var.name_prefix
  environment                     = "dev"
  ami_id                          = var.ami_id
  key_name                        = var.key_name
  instance_type                   = var.instance_type
  subnet_id                       = var.subnet_ids_by_az[var.primary_az]
  associate_public_ip_address     = var.associate_public_ip_address
  root_volume_size_gb             = var.root_volume_size_gb
  root_volume_type                = var.root_volume_type
  server_security_group_id        = local.use_existing_security_groups ? var.existing_server_security_group_id : module.security_groups[0].server_security_group_id
  worker_shared_security_group_id = local.use_existing_security_groups ? var.existing_worker_shared_security_group_id : module.security_groups[0].worker_shared_security_group_id
  node_definitions                = var.node_definitions
}

module "storage" {
  source = "../../modules/storage"

  name_prefix = var.name_prefix
  environment = "dev"
  volume_definitions = {
    db = {
      availability_zone = var.primary_az
      instance_id       = module.k3s_nodes.instance_ids_by_name[module.k3s_nodes.node_names_by_role.db[0]]
      size_gb           = var.db_volume_size_gb
      volume_type       = var.db_volume_type
      device_name       = var.db_device_name
    }
    llm_obs = {
      availability_zone = var.primary_az
      instance_id       = module.k3s_nodes.instance_ids_by_name[module.k3s_nodes.node_names_by_role.llm_obs[0]]
      size_gb           = var.llm_obs_volume_size_gb
      volume_type       = var.llm_obs_volume_type
      device_name       = var.llm_obs_device_name
    }
    clickhouse = {
      availability_zone = var.primary_az
      instance_id       = module.k3s_nodes.instance_ids_by_name[module.k3s_nodes.node_names_by_role.clickhouse[0]]
      size_gb           = var.clickhouse_volume_size_gb
      volume_type       = var.clickhouse_volume_type
      device_name       = var.clickhouse_device_name
    }
  }
}
