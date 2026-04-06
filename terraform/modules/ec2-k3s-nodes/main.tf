locals {
  server_node_name = one([
    for name, definition in var.node_definitions : name
    if definition.role == "server"
  ])

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

resource "aws_instance" "node" {
  for_each = var.node_definitions

  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = try(each.value.subnet_id, var.subnet_id)
  associate_public_ip_address = try(each.value.associate_public_ip_address, var.associate_public_ip_address)
  vpc_security_group_ids = each.value.role == "server" ? [
    var.server_security_group_id,
    ] : [
    var.worker_shared_security_group_id,
  ]

  root_block_device {
    volume_size = try(each.value.root_volume_size_gb, var.root_volume_size_gb)
    volume_type = var.root_volume_type
    encrypted   = true
  }

  user_data = var.k3s_bootstrap_token == null ? null : (
    each.value.role == "server"
    ? templatefile("${path.module}/templates/server-user-data.sh.tftpl", {
      k3s_token       = var.k3s_bootstrap_token
      k3s_node_name   = each.key
      k3s_node_labels = local.node_role_labels[each.key]
      k3s_node_taints = local.node_role_taints[each.key]
      k3s_server_args = var.k3s_server_extra_args
    })
    : templatefile("${path.module}/templates/agent-user-data.sh.tftpl", {
      k3s_server_host = aws_instance.node[local.server_node_name].private_ip
      k3s_token       = var.k3s_bootstrap_token
      k3s_node_name   = each.key
      k3s_node_labels = local.node_role_labels[each.key]
      k3s_node_taints = local.node_role_taints[each.key]
      k3s_agent_args  = lookup(var.k3s_agent_extra_args_by_role, each.value.role, "")
    })
  )

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
