locals {
  common_inputs = {
    aws_region  = "us-east-1"
    name_prefix = "k3s-dev"
  }
}

# Root Terragrunt configuration for environment composition.
# Resource logic stays in terraform/ modules and environment roots.
