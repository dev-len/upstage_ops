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

variable "existing_server_security_group_id" {
  description = "Existing security group ID to use for the K3S bootstrap server node instead of creating one."
  type        = string
  default     = null

  validation {
    condition = (
      var.existing_server_security_group_id == null ||
      can(regex("^sg-[0-9a-z]+$", var.existing_server_security_group_id))
    )
    error_message = "existing_server_security_group_id must look like an AWS security group ID."
  }
}

variable "existing_worker_shared_security_group_id" {
  description = "Existing security group ID to use for shared K3S worker nodes instead of creating one."
  type        = string
  default     = null

  validation {
    condition = (
      var.existing_worker_shared_security_group_id == null ||
      can(regex("^sg-[0-9a-z]+$", var.existing_worker_shared_security_group_id))
    )
    error_message = "existing_worker_shared_security_group_id must look like an AWS security group ID."
  }
}

variable "subnet_ids_by_az" {
  type        = map(string)
  description = "Existing subnet IDs keyed by AZ. Subnets are not created by this configuration."
}

variable "primary_az" {
  description = "Primary availability zone used for the default single-AZ baseline placement."
  type        = string
  default     = "us-east-1a"

  validation {
    condition     = contains(keys(var.subnet_ids_by_az), var.primary_az)
    error_message = "primary_az must match one of the keys in subnet_ids_by_az."
  }

  nullable = false
}

variable "ami_id" {
  description = "AMI ID used for the baseline EC2 nodes."
  type        = string
}

variable "key_name" {
  description = "Existing EC2 key pair name used for SSH access."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type used for the baseline nodes."
  type        = string
  default     = "t3.medium"
}

variable "associate_public_ip_address" {
  description = "Whether nodes should receive public IPv4 addresses by default."
  type        = bool
  default     = true
}

variable "root_volume_size_gb" {
  description = "Default root volume size in GiB."
  type        = number
  default     = 16
}

variable "root_volume_type" {
  description = "Default root EBS volume type."
  type        = string
  default     = "gp3"
}

variable "node_definitions" {
  description = "Role-aware node definitions keyed by logical node name."
  type = map(object({
    role                        = string
    subnet_id                   = optional(string)
    associate_public_ip_address = optional(bool)
    root_volume_size_gb         = optional(number)
  }))
  default = {
    server = {
      role = "server"
    }
    app_1 = {
      role = "app"
    }
    app_2 = {
      role = "app"
    }
    metrics = {
      role = "metrics"
    }
    logs_traces = {
      role = "logs_traces"
    }
    db = {
      role = "db"
    }
    llm_obs = {
      role = "llm_obs"
    }
    clickhouse = {
      role = "clickhouse"
    }
  }
}

variable "db_volume_size_gb" {
  description = "EBS data volume size in GiB for the db node."
  type        = number
  default     = 40
}

variable "db_volume_type" {
  description = "EBS volume type for the db node."
  type        = string
  default     = "gp3"
}

variable "db_device_name" {
  description = "Linux device name used to attach the db data volume."
  type        = string
  default     = "/dev/sdf"
}

variable "llm_obs_volume_size_gb" {
  description = "EBS data volume size in GiB for the llm_obs node."
  type        = number
  default     = 40
}

variable "llm_obs_volume_type" {
  description = "EBS volume type for the llm_obs node."
  type        = string
  default     = "gp3"
}

variable "llm_obs_device_name" {
  description = "Linux device name used to attach the llm_obs data volume."
  type        = string
  default     = "/dev/sdg"
}

variable "clickhouse_volume_size_gb" {
  description = "EBS data volume size in GiB for the clickhouse node."
  type        = number
  default     = 100
}

variable "clickhouse_volume_type" {
  description = "EBS volume type for the clickhouse node."
  type        = string
  default     = "gp3"
}

variable "clickhouse_device_name" {
  description = "Linux device name used to attach the clickhouse data volume."
  type        = string
  default     = "/dev/sdh"
}
