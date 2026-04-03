output "server_security_group_id" {
  value       = local.use_existing_security_groups ? var.existing_server_security_group_id : module.security_groups[0].server_security_group_id
  description = "Security group ID for the bootstrap K3S server node."
}

output "worker_shared_security_group_id" {
  value       = local.use_existing_security_groups ? var.existing_worker_shared_security_group_id : module.security_groups[0].worker_shared_security_group_id
  description = "Security group ID shared by bootstrap K3S worker nodes."
}

output "main_node_security_group_id" {
  value       = local.use_existing_security_groups ? var.existing_server_security_group_id : module.security_groups[0].main_node_security_group_id
  description = "Compatibility alias for server_security_group_id."
}

output "sub_node_security_group_id" {
  value       = local.use_existing_security_groups ? var.existing_worker_shared_security_group_id : module.security_groups[0].sub_node_security_group_id
  description = "Compatibility alias for worker_shared_security_group_id."
}

output "bastion_security_group_id" {
  value = var.enable_bastion ? (
    local.use_existing_security_groups ? var.existing_bastion_security_group_id : module.security_groups[0].bastion_security_group_id
  ) : null
  description = "Security group ID for the bastion host."
}

output "k3s_instance_ids_by_name" {
  value       = module.k3s_nodes.instance_ids_by_name
  description = "EC2 instance IDs keyed by logical K3S node name."
}

output "k3s_private_ips_by_name" {
  value       = module.k3s_nodes.private_ips_by_name
  description = "Private IPv4 addresses keyed by logical K3S node name."
}

output "k3s_public_ips_by_name" {
  value       = module.k3s_nodes.public_ips_by_name
  description = "Public IPv4 addresses keyed by logical K3S node name."
}

output "k3s_node_roles_by_name" {
  value       = module.k3s_nodes.node_roles_by_name
  description = "K3S node roles keyed by logical node name."
}

output "k3s_node_names_by_role" {
  value       = module.k3s_nodes.node_names_by_role
  description = "Logical K3S node names grouped by role."
}

output "k3s_server_instance_id" {
  value       = module.k3s_nodes.server_instance_id
  description = "EC2 instance ID for the K3S bootstrap server node."
}

output "k3s_server_private_ip" {
  value       = module.k3s_nodes.server_private_ip
  description = "Private IPv4 address for the K3S bootstrap server node."
}

output "k3s_server_public_ip" {
  value       = module.k3s_nodes.server_public_ip
  description = "Public IPv4 address for the K3S bootstrap server node."
}

output "storage_volume_ids_by_role" {
  value       = var.enable_storage ? module.storage[0].volume_ids_by_role : {}
  description = "EBS volume IDs keyed by storage role."
}

output "storage_attachment_ids_by_role" {
  value       = var.enable_storage ? module.storage[0].attachment_ids_by_role : {}
  description = "EBS volume attachment IDs keyed by storage role."
}

output "storage_device_names_by_role" {
  value       = var.enable_storage ? module.storage[0].device_names_by_role : {}
  description = "EBS device names keyed by storage role."
}

output "k3s_server_endpoint" {
  value       = "https://${module.k3s_nodes.server_private_ip}:6443"
  description = "K3S bootstrap server endpoint for join and kubeconfig wiring."
}

output "bastion_instance_id" {
  value       = var.enable_bastion ? aws_instance.bastion[0].id : null
  description = "EC2 instance ID for the bastion host."
}

output "bastion_private_ip" {
  value       = var.enable_bastion ? aws_instance.bastion[0].private_ip : null
  description = "Private IPv4 address for the bastion host."
}

output "bastion_public_ip" {
  value       = var.enable_bastion ? aws_instance.bastion[0].public_ip : null
  description = "Public IPv4 address for the bastion host."
}
