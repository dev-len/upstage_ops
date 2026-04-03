output "server_security_group_id" {
  value       = module.security_groups.server_security_group_id
  description = "Security group ID for the bootstrap K3S server node."
}

output "worker_shared_security_group_id" {
  value       = module.security_groups.worker_shared_security_group_id
  description = "Security group ID shared by bootstrap K3S worker nodes."
}

output "main_node_security_group_id" {
  value       = module.security_groups.main_node_security_group_id
  description = "Compatibility alias for server_security_group_id."
}

output "sub_node_security_group_id" {
  value       = module.security_groups.sub_node_security_group_id
  description = "Compatibility alias for worker_shared_security_group_id."
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
  value       = module.storage.volume_ids_by_role
  description = "EBS volume IDs keyed by storage role."
}

output "storage_attachment_ids_by_role" {
  value       = module.storage.attachment_ids_by_role
  description = "EBS volume attachment IDs keyed by storage role."
}

output "storage_device_names_by_role" {
  value       = module.storage.device_names_by_role
  description = "EBS device names keyed by storage role."
}

output "k3s_server_endpoint" {
  value       = "https://${module.k3s_nodes.server_private_ip}:6443"
  description = "K3S bootstrap server endpoint for join and kubeconfig wiring."
}
