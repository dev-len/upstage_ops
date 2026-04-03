variable "name_prefix" {
  description = "Prefix used in security group names and tags."
  type        = string
  default     = "k3s"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }

  nullable = false
}

variable "vpc_id" {
  description = "Existing VPC ID where the security groups will be created."
  type        = string

  validation {
    condition     = can(regex("^vpc-[0-9a-z]+$", var.vpc_id))
    error_message = "vpc_id must look like an AWS VPC ID, for example vpc-0123456789abcdef0."
  }

  nullable = false
}

variable "admin_cidr" {
  description = "Admin IPv4 CIDR allowed to access the bootstrap server and shared worker nodes over SSH."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid IPv4 CIDR block, for example 203.0.113.10/32."
  }

  nullable = false
}
