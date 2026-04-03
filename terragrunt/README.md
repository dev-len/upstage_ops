# Terragrunt Layout

This directory is the environment entrypoint layer for Terraform modules in [terraform](/Users/len/Desktop/project/k8s/terraform).

## Structure

- `../root.hcl`
  - shared Terragrunt defaults and common inputs
- `dev/terragrunt.hcl`
  - `dev` environment entrypoint
- `dev/inputs.hcl.example`
  - example environment-specific inputs

## Usage

1. Copy `dev/inputs.hcl.example` to `dev/inputs.hcl`.
2. Fill in the real `vpc_id`, `admin_cidr`, `subnet_ids_by_az`, `ami_id`, and `key_name`.
   - If the account cannot create bootstrap security groups, pre-create them and set both `existing_server_security_group_id` and `existing_worker_shared_security_group_id`.
   - CloudShell example:
     ```bash
     SERVER_SG_ID=$(aws ec2 create-security-group \
       --group-name k3s-dev-server-sg \
       --description "Bootstrap SG for K3S server" \
       --vpc-id vpc-xxxxxxxxxxxxxxxxx \
       --query 'GroupId' \
       --output text)

     WORKER_SG_ID=$(aws ec2 create-security-group \
       --group-name k3s-dev-worker-shared-sg \
       --description "Bootstrap SG for shared K3S workers" \
       --vpc-id vpc-xxxxxxxxxxxxxxxxx \
       --query 'GroupId' \
       --output text)
     ```
   - Add ingress rules only. Do not modify outbound rules in the training account.
   - Then set:
     ```hcl
     existing_server_security_group_id        = "sg-xxxxxxxxxxxxxxxxx"
     existing_worker_shared_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
     ```
3. Review optional baseline inputs:
   - `primary_az`
   - `instance_type`
   - `associate_public_ip_address`
   - `enable_storage`
   - `root_volume_size_gb`
   - `root_volume_type`
   - `db_root_volume_size_gb`, `llm_obs_root_volume_size_gb`, `clickhouse_root_volume_size_gb`
   - `db_*`, `llm_obs_*`, `clickhouse_*` storage inputs
   - `node_definitions` if logical node names or placement must change
3. In AWS CloudShell, move cache paths to `/tmp` before running validation or plan:
   ```bash
   mkdir -p /tmp/.terragrunt-cache
   mkdir -p /tmp/.terraform-plugin-cache

   export TG_DOWNLOAD_DIR="/tmp/.terragrunt-cache"
   export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugin-cache"
   ```
4. Run Terragrunt from `terragrunt/dev`.

## Notes

- Terragrunt composes environments; Terraform still owns resources and module logic.
- Existing VPC and subnets are treated as inputs, not managed resources.
- `terragrunt/dev/terragrunt.hcl` merges root defaults with `inputs.hcl`.
- `terraform.source` uses `../../terraform//environments/dev` so Terragrunt copies the whole `terraform/` tree and relative module paths remain valid in cache.
- Use `terragrunt hclfmt --check` for HCL format validation.
- In CloudShell, prefer `TG_DOWNLOAD_DIR` over deprecated `TERRAGRUNT_DOWNLOAD`.
- In the training account, bootstrap security-group outbound must be left unmanaged because any Terraform-managed egress update triggers `ec2:RevokeSecurityGroupEgress`, which is denied by policy.
- The bootstrap SG module therefore ignores `egress` drift on create/update and only manages ingress rules.
- In the training account, prefer `enable_storage = false` because `ec2:CreateVolume` may also be denied.
- When storage is disabled, grow the root volume for `db`, `llm_obs`, and `clickhouse` instead of provisioning separate EBS volumes.
- Validation and review expectations are defined in [validation-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/validation-baseline.md).
