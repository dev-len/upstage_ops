# Terraform layout

This directory assumes the AWS VPC and subnets may already exist and may not be manageable from the current account.

Current architecture baseline:

- default VPC / existing subnets
- K3S 7-node role-separated topology
- Terraform starts with security-group validation first, then expands toward the full topology

Related docs:

- `../docs/architecture.md`
- `../docs/network-inventory.md`
- `../docs/adr/006-adopt-k3s-seven-node-topology.md`

## Current structure

- `modules/security-groups`
  - Reusable K3S server/worker security groups for initial validation
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

## Current gap vs target architecture

The current Terraform code does not model the full 7-node topology yet.

- implemented now:
  - server SG
  - worker SG
- not modeled yet:
  - per-role EC2 layout
  - EBS attachment strategy for DB / ClickHouse / Langfuse
  - role-specific security groups
  - ingress exposure rules (`80/443`)

This is intentional. The repository is currently at the "prove network and K3S baseline safely inside account limits" stage.

## Next step

Use this module first to validate private-network K3S communication with:

- one main node
- one sub node
- existing VPC/subnet placement

After that, expand in this order:

1. add EC2 definitions for the 7-node baseline
2. decide whether workers keep one shared SG or split by role
3. add persistent-volume related inputs for DB / ClickHouse / Langfuse nodes
4. add ingress-facing rules only after external exposure is confirmed
