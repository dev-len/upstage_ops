# security-groups module

This module creates the minimum AWS security groups required for an initial two-tier K3S layout:

- `server`: bootstrap K3S server/control-plane node
- `worker-shared`: bootstrap security group shared by K3S worker nodes
- `bastion` (optional): SSH entrypoint for private fleet access

This module is intentionally narrower than the current 7-node architecture baseline.
It is the bootstrap layer for validating K3S communication before role-specific infrastructure is added.

For compatibility, the Terraform resource addresses and legacy outputs still use the existing
`main_node` and `sub_node` naming. Semantically, treat them as:

- `main_node` -> `server`
- `sub_node` -> `worker-shared`

It assumes:

- the VPC already exists
- subnets already exist and are managed outside Terraform
- SSH should be limited to an admin CIDR
- K3S node-to-node traffic should be allowed via security-group references, not broad CIDR rules

## Inputs

- `vpc_id`
- `admin_cidr`
- `bastion_ssh_port` (optional)
- `name_prefix` (optional)
- `enable_bastion` (optional)

## Outputs

- `server_security_group_id`
- `worker_shared_security_group_id`
- `main_node_security_group_id`
- `sub_node_security_group_id`
- `bastion_security_group_id`

The `main_node_*` and `sub_node_*` outputs are compatibility aliases for the explicit
`server_*` and `worker_shared_*` semantics.

## Ports included

- `bastion_ssh_port/tcp` from `admin_cidr` into `bastion`
- `22/tcp` from `admin_cidr` into `server` and `worker-shared`
- `22/tcp` from `bastion` to `server` and `worker-shared` when enabled
- `6443/tcp` from shared worker nodes to the server node
- `8472/udp` server<->server, server<->worker-shared, worker-shared<->worker-shared
- `10250/tcp` server<->server, server<->worker-shared, worker-shared<->worker-shared

## Notes

- This module is enough for initial private-network K3S validation.
- It is not the final security-group model for the 7-node topology.
- It does not include `80/443`, NodePort ranges, or HA etcd ports.
- It does not separate `app`, `metrics`, `logs-traces`, `db`, `llm-obs`, and `clickhouse` worker roles yet.
- It intentionally models one bootstrap `server` SG, one bootstrap `worker-shared` SG, and an optional `bastion` SG only.
- Outbound is intentionally left unmanaged in Terraform during bootstrap.
- AWS keeps the default allow-all egress rule on new security groups.
- This is required in the training account because any Terraform-managed egress flow triggers `ec2:RevokeSecurityGroupEgress`, which is explicitly denied.
- The module uses `lifecycle.ignore_changes = [egress]` so Terraform does not try to reconcile the provider-created default outbound rule.
- If outbound is later restricted, re-check IAM permissions before making Terraform own bootstrap egress policy.
