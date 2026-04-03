resource "aws_ebs_volume" "role" {
  for_each = var.volume_definitions

  availability_zone = each.value.availability_zone
  size              = each.value.size_gb
  type              = each.value.volume_type
  encrypted         = true

  tags = {
    Name        = "${var.name_prefix}-${each.key}-data"
    Cluster     = var.name_prefix
    StorageRole = each.key
    Environment = var.environment
  }
}

resource "aws_volume_attachment" "role" {
  for_each = var.volume_definitions

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.role[each.key].id
  instance_id = each.value.instance_id

  stop_instance_before_detaching = true
}
