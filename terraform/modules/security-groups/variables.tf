variable "name_prefix" {
  type        = string
  description = "Prefix used in security group names and tags."
  default     = "k3s"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID where the security groups will be created."
}

variable "admin_cidr" {
  type        = string
  description = "Admin public CIDR allowed to access nodes over SSH."
}

