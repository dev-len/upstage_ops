output "server_security_group_id" {
  description = "Security group ID for the bootstrap K3S server node."
  value       = aws_security_group.main_node.id
}

output "worker_shared_security_group_id" {
  description = "Security group ID shared by bootstrap K3S worker nodes."
  value       = aws_security_group.sub_node.id
}

output "main_node_security_group_id" {
  description = "Compatibility alias for server_security_group_id."
  value       = aws_security_group.main_node.id
}

output "sub_node_security_group_id" {
  description = "Compatibility alias for worker_shared_security_group_id."
  value       = aws_security_group.sub_node.id
}
