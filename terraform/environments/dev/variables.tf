variable "aws_region" {
  type        = string
  description = "AWS region used for the dev environment."
  default     = "us-east-1"
}

variable "name_prefix" {
  type        = string
  description = "Name prefix used for resources."
  default     = "k3s-dev"
}

variable "vpc_id" {
  type        = string
  description = "Existing VPC ID for the default or target VPC."
}

variable "admin_cidr" {
  type        = string
  description = "Admin CIDR allowed to SSH into nodes."
}

variable "subnet_ids_by_az" {
  type        = map(string)
  description = "Existing subnet IDs keyed by AZ. Subnets are not created by this configuration."
}

