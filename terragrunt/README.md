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
3. Review optional baseline inputs:
   - `primary_az`
   - `instance_type`
   - `associate_public_ip_address`
   - `root_volume_size_gb`
   - `root_volume_type`
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
- In the training account, security groups must keep bootstrap outbound as allow-all because `ec2:RevokeSecurityGroupEgress` is denied by policy.
- Validation and review expectations are defined in [validation-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/validation-baseline.md).
