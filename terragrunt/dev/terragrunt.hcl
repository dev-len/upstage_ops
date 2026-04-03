include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

terraform {
  source = "../../terraform//environments/dev"
}

locals {
  environment_inputs = try(read_terragrunt_config("inputs.hcl").inputs, {})
}

inputs = merge(
  include.root.locals.common_inputs,
  local.environment_inputs,
)
