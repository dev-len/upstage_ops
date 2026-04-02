# Terraform layout

This directory assumes the AWS VPC and subnets may already exist and may not be manageable from the current account.

## Current structure

- `modules/security-groups`
  - Reusable K3S main/sub node security groups
- `environments/dev`
  - Example environment wiring for the security-group module

## Existing subnet context

The current environment is assumed to have existing subnets in `us-east-1` similar to:

- `us-east-1a` -> `172.31.0.0/20`
- `us-east-1b` -> `172.31.80.0/20`
- `us-east-1c` -> `172.31.16.0/20`
- `us-east-1d` -> `172.31.32.0/20`
- `us-east-1e` -> `172.31.48.0/20`
- `us-east-1f` -> `172.31.64.0/20`

Subnet IDs are intentionally treated as inputs and must be filled in manually in `terraform.tfvars`.

## Next step

Use this module first to validate private-network K3S communication with:

- one main node
- one sub node
- existing VPC/subnet placement

