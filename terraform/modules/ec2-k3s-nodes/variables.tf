variable "name_prefix" {
  description = "Name prefix applied to instance names and tags."
  type        = string
  default     = "k3s"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }

  nullable = false
}

variable "environment" {
  description = "Environment tag attached to all instances."
  type        = string
  default     = "dev"

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }

  nullable = false
}

variable "ami_id" {
  description = "AMI ID used for all K3S baseline instances."
  type        = string

  validation {
    condition     = can(regex("^ami-[0-9a-z]+$", var.ami_id))
    error_message = "ami_id must look like an AWS AMI ID, for example ami-0123456789abcdef0."
  }

  nullable = false
}

variable "key_name" {
  description = "Existing EC2 key pair name used for SSH access."
  type        = string

  validation {
    condition     = length(trimspace(var.key_name)) > 0
    error_message = "key_name must not be empty."
  }

  nullable = false
}

variable "instance_type" {
  description = "EC2 instance type used for the baseline nodes."
  type        = string
  default     = "t3.medium"

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type must not be empty."
  }

  nullable = false
}

variable "subnet_id" {
  description = "Default subnet ID used when a node definition does not override subnet placement."
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-z]+$", var.subnet_id))
    error_message = "subnet_id must look like an AWS subnet ID, for example subnet-0123456789abcdef0."
  }

  nullable = false
}

variable "associate_public_ip_address" {
  description = "Whether instances should receive public IPv4 addresses by default."
  type        = bool
  default     = true

  nullable = false
}

variable "root_volume_size_gb" {
  description = "Default root volume size in GiB."
  type        = number
  default     = 16

  validation {
    condition     = var.root_volume_size_gb >= 16
    error_message = "root_volume_size_gb must be at least 16."
  }

  nullable = false
}

variable "root_volume_type" {
  description = "Default root EBS volume type."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp2, gp3."
  }

  nullable = false
}

variable "server_security_group_id" {
  description = "Security group ID for the K3S bootstrap server node."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-z]+$", var.server_security_group_id))
    error_message = "server_security_group_id must look like an AWS security group ID."
  }

  nullable = false
}

variable "worker_shared_security_group_id" {
  description = "Security group ID shared by K3S worker baseline nodes."
  type        = string

  validation {
    condition     = can(regex("^sg-[0-9a-z]+$", var.worker_shared_security_group_id))
    error_message = "worker_shared_security_group_id must look like an AWS security group ID."
  }

  nullable = false
}

variable "k3s_bootstrap_token" {
  description = "Shared K3S token used to bootstrap the server and agents automatically via user_data. Leave null to skip bootstrap automation."
  type        = string
  default     = null
  sensitive   = true
}

variable "k3s_server_extra_args" {
  description = "Optional extra arguments appended to the K3S server install command."
  type        = string
  default     = ""
}

variable "k3s_agent_extra_args_by_role" {
  description = "Optional extra K3S agent arguments keyed by logical role."
  type        = map(string)
  default     = {}
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

  validation {
    condition = length([
      for definition in values(var.node_definitions) : definition
      if contains(["server", "app", "metrics", "logs_traces", "db", "llm_obs", "clickhouse"], definition.role)
    ]) == length(var.node_definitions)
    error_message = "node_definitions.role must be one of: server, app, metrics, logs_traces, db, llm_obs, clickhouse."
  }

  validation {
    condition     = length([for definition in values(var.node_definitions) : definition if definition.role == "server"]) == 1
    error_message = "node_definitions must contain exactly one server role entry."
  }

  nullable = false
}
