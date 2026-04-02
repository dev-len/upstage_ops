output "main_node_security_group_id" {
  description = "Security group ID for the K3S main/server node."
  value       = aws_security_group.main_node.id
}

output "sub_node_security_group_id" {
  description = "Security group ID for the K3S sub/agent nodes."
  value       = aws_security_group.sub_node.id
}

