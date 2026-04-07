locals {
  use_existing_security_groups = (
    var.existing_server_security_group_id != null &&
    var.existing_worker_shared_security_group_id != null
  )
  bastion_subnet_id = coalesce(var.bastion_subnet_id, var.subnet_ids_by_az[var.primary_az])
  bastion_key_name  = coalesce(var.bastion_key_name, var.key_name)
  use_existing_bastion_security_group = (
    var.enable_bastion &&
    local.use_existing_security_groups &&
    var.existing_bastion_security_group_id != null
  )

  root_volume_overrides_by_name = {
    db         = var.db_root_volume_size_gb
    llm_obs    = var.llm_obs_root_volume_size_gb
    clickhouse = var.clickhouse_root_volume_size_gb
  }

  effective_node_definitions = {
    for name, definition in var.node_definitions :
    name => merge(
      definition,
      lookup(local.root_volume_overrides_by_name, name, null) != null ? {
        root_volume_size_gb = lookup(local.root_volume_overrides_by_name, name, null)
      } : {}
    )
  }

  manage_existing_bastion_ingress = (
    local.use_existing_bastion_security_group &&
    var.manage_existing_bastion_ssh_ingress_rules
  )

  existing_bastion_has_admin_ssh  = local.manage_existing_bastion_ingress ? data.external.existing_sg_rule_status[0].result.bastion_has_admin_ssh == "true" : false
  existing_server_has_bastion_ssh = local.manage_existing_bastion_ingress ? data.external.existing_sg_rule_status[0].result.server_has_bastion_ssh == "true" : false
  existing_worker_has_bastion_ssh = local.manage_existing_bastion_ingress ? data.external.existing_sg_rule_status[0].result.worker_has_bastion_ssh == "true" : false
}

data "external" "existing_sg_rule_status" {
  count = local.manage_existing_bastion_ingress ? 1 : 0

  program = ["bash", "${path.module}/scripts/check-existing-sg-rules.sh"]

  query = {
    aws_region    = var.aws_region
    admin_cidr    = var.admin_cidr
    bastion_port  = tostring(var.bastion_ssh_port)
    bastion_sg_id = var.existing_bastion_security_group_id
    server_sg_id  = var.existing_server_security_group_id
    worker_sg_id  = var.existing_worker_shared_security_group_id
  }
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

check "bastion_security_group_override" {
  assert {
    condition = (
      !var.enable_bastion ||
      !local.use_existing_security_groups ||
      var.existing_bastion_security_group_id != null
    )
    error_message = "existing_bastion_security_group_id is required when enable_bastion is true and server/worker security groups are injected."
  }
}

module "security_groups" {
  count  = local.use_existing_security_groups ? 0 : 1
  source = "../../modules/security-groups"

  name_prefix      = var.name_prefix
  vpc_id           = var.vpc_id
  admin_cidr       = var.admin_cidr
  bastion_ssh_port = var.bastion_ssh_port
  enable_bastion   = var.enable_bastion
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
  node_definitions                = local.effective_node_definitions
  bastion_node_authorized_key     = var.enable_bastion && var.bootstrap_bastion_helpers ? tls_private_key.bastion_node_access[0].public_key_openssh : ""
  k3s_bootstrap_token             = var.k3s_bootstrap_token
  k3s_server_extra_args           = var.k3s_server_extra_args
  k3s_agent_extra_args_by_role    = var.k3s_agent_extra_args_by_role
}

resource "aws_vpc_security_group_ingress_rule" "existing_server_ssh_from_bastion" {
  count = (
    local.manage_existing_bastion_ingress &&
    !local.existing_server_has_bastion_ssh
  ) ? 1 : 0

  security_group_id            = var.existing_server_security_group_id
  referenced_security_group_id = var.existing_bastion_security_group_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "SSH from bastion"
}

resource "aws_vpc_security_group_ingress_rule" "existing_worker_ssh_from_bastion" {
  count = (
    local.manage_existing_bastion_ingress &&
    !local.existing_worker_has_bastion_ssh
  ) ? 1 : 0

  security_group_id            = var.existing_worker_shared_security_group_id
  referenced_security_group_id = var.existing_bastion_security_group_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "SSH from bastion"
}

resource "aws_vpc_security_group_ingress_rule" "existing_bastion_ssh_from_admin" {
  count = (
    local.manage_existing_bastion_ingress &&
    !local.existing_bastion_has_admin_ssh
  ) ? 1 : 0

  security_group_id = var.existing_bastion_security_group_id
  cidr_ipv4         = var.admin_cidr
  from_port         = var.bastion_ssh_port
  to_port           = var.bastion_ssh_port
  ip_protocol       = "tcp"
  description       = "SSH from admin"
}

resource "tls_private_key" "bastion_node_access" {
  count = (
    var.enable_bastion &&
    var.bootstrap_bastion_helpers
  ) ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_instance" "bastion" {
  count = var.enable_bastion ? 1 : 0

  ami                         = var.ami_id
  instance_type               = var.bastion_instance_type
  key_name                    = local.bastion_key_name
  subnet_id                   = local.bastion_subnet_id
  associate_public_ip_address = var.bastion_associate_public_ip_address
  vpc_security_group_ids = [
    local.use_existing_security_groups ? var.existing_bastion_security_group_id : module.security_groups[0].bastion_security_group_id,
  ]

  root_block_device {
    volume_size = var.root_volume_size_gb
    volume_type = var.root_volume_type
    encrypted   = true
  }

  user_data = templatefile("${path.module}/templates/bastion-user-data.sh.tftpl", {
    aws_region                = var.aws_region
    cluster_prefix            = var.name_prefix
    bastion_ssh_port          = var.bastion_ssh_port
    bootstrap_bastion_helpers = var.bootstrap_bastion_helpers
    bastion_node_private_key  = var.bootstrap_bastion_helpers ? tls_private_key.bastion_node_access[0].private_key_openssh : ""
  })

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }

  tags = {
    Name        = "${var.name_prefix}-bastion"
    Cluster     = var.name_prefix
    Environment = "dev"
    Role        = "bastion"
  }
}

module "storage" {
  count  = var.enable_storage ? 1 : 0
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
