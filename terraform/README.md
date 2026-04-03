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
- `../docs/tasks/validation-baseline.md`

## Current structure

- `modules/security-groups`
  - Reusable K3S server/worker security groups for initial validation
- `modules/ec2-k3s-nodes`
  - Role-aware EC2 baseline for the 7-node topology
- `modules/storage`
  - Optional EBS volume and attachment layer for stateful roles
- `environments/dev`
  - Dev environment wiring for SG, EC2, and storage baseline modules
- `../root.hcl`
  - Shared Terragrunt root config
- `../terragrunt/dev/terragrunt.hcl`
  - Dev environment entrypoint
- `../bootstrap/k3s`
  - K3S server/agent bootstrap assets
- `../deployments/observability`
  - Observability placement values
- `../deployments/langfuse`
  - Langfuse placement values

## Validation baseline

The common validation, security, and review baseline for all lanes lives in:

- `../docs/tasks/validation-baseline.md`

Use that document as the default reference when deciding:

- what must run locally
- what must run in CloudShell or CI
- what is blocked by missing binaries or IAM constraints
- what evidence must be reported in a PR

## Existing subnet context

The current environment is assumed to have existing subnets in `us-east-1` similar to:

- `us-east-1a` -> `172.31.0.0/20`
- `us-east-1b` -> `172.31.80.0/20`
- `us-east-1c` -> `172.31.16.0/20`
- `us-east-1d` -> `172.31.32.0/20`
- `us-east-1e` -> `172.31.48.0/20`
- `us-east-1f` -> `172.31.64.0/20`

Subnet IDs are intentionally treated as inputs and must be filled in manually in `terragrunt/dev/inputs.hcl` or a compatible environment-specific input file.

Security groups can also be treated as inputs when the current account cannot create bootstrap SGs without hitting IAM restrictions.
If both existing SG IDs are provided, the dev environment skips the SG module and reuses:

- `existing_server_security_group_id`
- `existing_worker_shared_security_group_id`

## Current gap vs target architecture

The current Terraform code does not model the full 7-node topology yet.

- implemented now:
  - server SG
  - worker-shared SG
  - baseline EC2 layout for server/app/metrics/logs-traces/db/llm-obs/clickhouse roles
  - optional EBS volume and attachment layer for db / llm-obs / clickhouse
- not modeled yet:
  - role-specific security groups
  - ingress exposure rules (`80/443`)

This is intentional. The repository is currently at the "prove network and K3S baseline safely inside account limits" stage.

Current contracts exposed from the dev environment include:

- `server_security_group_id`
- `worker_shared_security_group_id`
- `k3s_instance_ids_by_name`
- `k3s_private_ips_by_name`
- `k3s_public_ips_by_name`
- `k3s_node_roles_by_name`
- `k3s_node_names_by_role`
- `k3s_server_endpoint`
- `storage_volume_ids_by_role`
- `storage_attachment_ids_by_role`
- `storage_device_names_by_role`

For the training account, prefer:

- existing SG ID injection for bootstrap networking
- `enable_storage = false`
- larger root volumes for `db`, `llm_obs`, and `clickhouse`

## Next step

Use this module first to validate private-network K3S communication with:

- one server node
- shared worker nodes
- existing VPC/subnet placement

After that, expand in this order:

1. decide whether workers keep one shared SG or split by role
2. use `../bootstrap/k3s` to install K3S and apply role labels or optional taints
3. add workload placement manifests and scheduling rules
4. add ingress-facing rules only after external exposure is confirmed
