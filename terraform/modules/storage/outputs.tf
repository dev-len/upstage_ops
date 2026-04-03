output "volume_ids_by_role" {
  description = "EBS volume IDs keyed by storage role."
  value = {
    for role, volume in aws_ebs_volume.role : role => volume.id
  }
}

output "attachment_ids_by_role" {
  description = "Volume attachment IDs keyed by storage role."
  value = {
    for role, attachment in aws_volume_attachment.role : role => attachment.id
  }
}

output "device_names_by_role" {
  description = "Device names keyed by storage role."
  value = {
    for role, definition in var.volume_definitions : role => definition.device_name
  }
}
