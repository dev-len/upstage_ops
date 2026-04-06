locals {
  server_node_name = one([
    for name, definition in var.node_definitions : name
    if definition.role == "server"
  ])

  server_node_definition = var.node_definitions[local.server_node_name]

  worker_node_definitions = {
    for name, definition in var.node_definitions : name => definition
    if definition.role != "server"
  }

  node_role_labels = {
    for name, definition in var.node_definitions :
    name => "topology.k3s.io/role=${replace(definition.role, "_", "-")}"
  }

  node_role_taints = {
    for name, definition in var.node_definitions :
    name => (
      contains(["metrics", "logs_traces", "db", "llm_obs", "clickhouse"], definition.role)
      ? "dedicated=${replace(definition.role, "_", "-")}:NoSchedule"
      : ""
    )
  }
}

resource "aws_instance" "server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = try(local.server_node_definition.subnet_id, var.subnet_id)
  associate_public_ip_address = try(local.server_node_definition.associate_public_ip_address, var.associate_public_ip_address)
  vpc_security_group_ids      = [var.server_security_group_id]

  root_block_device {
    volume_size = try(local.server_node_definition.root_volume_size_gb, var.root_volume_size_gb)
    volume_type = var.root_volume_type
    encrypted   = true
  }

  user_data = var.k3s_bootstrap_token == null ? null : templatefile("${path.module}/templates/server-user-data.sh.tftpl", {
    k3s_token       = var.k3s_bootstrap_token
    k3s_node_name   = local.server_node_name
    k3s_node_labels = local.node_role_labels[local.server_node_name]
    k3s_node_taints = local.node_role_taints[local.server_node_name]
    k3s_server_args = var.k3s_server_extra_args
  })

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }

  tags = {
    Name        = "${var.name_prefix}-${local.server_node_name}"
    Cluster     = var.name_prefix
    NodeName    = local.server_node_name
    NodeRole    = local.server_node_definition.role
    Environment = var.environment
  }
}

resource "aws_instance" "node" {
  for_each = local.worker_node_definitions

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = try(each.value.subnet_id, var.subnet_id)
  associate_public_ip_address = try(each.value.associate_public_ip_address, var.associate_public_ip_address)
  vpc_security_group_ids = [
    var.worker_shared_security_group_id,
  ]

  root_block_device {
    volume_size = try(each.value.root_volume_size_gb, var.root_volume_size_gb)
    volume_type = var.root_volume_type
    encrypted   = true
  }

  user_data = var.k3s_bootstrap_token == null ? null : templatefile("${path.module}/templates/agent-user-data.sh.tftpl", {
    k3s_server_host = aws_instance.server.private_ip
    k3s_token       = var.k3s_bootstrap_token
    k3s_node_name   = each.key
    k3s_node_labels = local.node_role_labels[each.key]
    k3s_node_taints = local.node_role_taints[each.key]
    k3s_agent_args  = lookup(var.k3s_agent_extra_args_by_role, each.value.role, "")
  })

  lifecycle {
    ignore_changes = [
      tags,
      tags_all,
    ]
  }

  tags = {
    Name        = "${var.name_prefix}-${each.key}"
    Cluster     = var.name_prefix
    NodeName    = each.key
    NodeRole    = each.value.role
    Environment = var.environment
  }
}
