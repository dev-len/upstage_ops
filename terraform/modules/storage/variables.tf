variable "name_prefix" {
  description = "Name prefix applied to storage tags."
  type        = string
  default     = "k3s"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "name_prefix must not be empty."
  }

  nullable = false
}

variable "environment" {
  description = "Environment tag attached to storage resources."
  type        = string
  default     = "dev"

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }

  nullable = false
}

variable "volume_definitions" {
  description = "Role-specific EBS volume definitions keyed by logical storage role."
  type = map(object({
    availability_zone = string
    instance_id       = string
    size_gb           = number
    volume_type       = string
    device_name       = string
  }))

  validation {
    condition = length([
      for role in keys(var.volume_definitions) : role
      if contains(["db", "llm_obs", "clickhouse"], role)
    ]) == length(var.volume_definitions)
    error_message = "volume_definitions keys must be limited to: db, llm_obs, clickhouse."
  }

  validation {
    condition = length([
      for definition in values(var.volume_definitions) : definition
      if definition.size_gb >= 10
    ]) == length(var.volume_definitions)
    error_message = "Each volume definition must use size_gb >= 10."
  }

  validation {
    condition = length([
      for definition in values(var.volume_definitions) : definition
      if contains(["gp2", "gp3"], definition.volume_type)
    ]) == length(var.volume_definitions)
    error_message = "Each volume definition must use volume_type gp2 or gp3."
  }

  nullable = false
}
