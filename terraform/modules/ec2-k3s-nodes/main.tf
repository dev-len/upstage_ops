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
