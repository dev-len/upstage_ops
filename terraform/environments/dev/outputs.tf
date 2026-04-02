output "main_node_security_group_id" {
  value       = module.security_groups.main_node_security_group_id
  description = "Security group ID for the main K3S node."
}

output "sub_node_security_group_id" {
  value       = module.security_groups.sub_node_security_group_id
  description = "Security group ID for the sub K3S nodes."
}

