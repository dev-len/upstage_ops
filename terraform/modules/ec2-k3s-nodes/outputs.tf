locals {
  node_roles_by_name = {
    for name, definition in var.node_definitions : name => definition.role
  }

  node_names_by_role = {
    for role in distinct(values(local.node_roles_by_name)) :
    role => [for name, node_role in local.node_roles_by_name : name if node_role == role]
  }
}

output "instance_ids_by_name" {
  description = "EC2 instance IDs keyed by logical node name."
  value = {
    for name, instance in aws_instance.node : name => instance.id
  }
}

output "private_ips_by_name" {
  description = "Private IPv4 addresses keyed by logical node name."
  value = {
    for name, instance in aws_instance.node : name => instance.private_ip
  }
}

output "public_ips_by_name" {
  description = "Public IPv4 addresses keyed by logical node name."
  value = {
    for name, instance in aws_instance.node : name => instance.public_ip
  }
}

output "node_roles_by_name" {
  description = "Node roles keyed by logical node name."
  value       = local.node_roles_by_name
}

output "node_names_by_role" {
  description = "Logical node names grouped by role."
  value       = local.node_names_by_role
}

output "server_instance_id" {
  description = "Instance ID for the K3S bootstrap server node."
  value       = aws_instance.node[local.node_names_by_role.server[0]].id
}

output "server_private_ip" {
  description = "Private IPv4 address for the K3S bootstrap server node."
  value       = aws_instance.node[local.node_names_by_role.server[0]].private_ip
}

output "server_public_ip" {
  description = "Public IPv4 address for the K3S bootstrap server node."
  value       = aws_instance.node[local.node_names_by_role.server[0]].public_ip
}
