# security-groups module

This module creates the minimum AWS security groups required for an initial two-tier K3S layout:

- `main_node`: K3S server/control plane
- `sub_node`: K3S agent/worker nodes

This module is intentionally narrower than the current 7-node architecture baseline.
It is the bootstrap layer for validating K3S communication before role-specific infrastructure is added.

It assumes:

- the VPC already exists
- subnets already exist and are managed outside Terraform
- SSH should be limited to an admin CIDR
- K3S node-to-node traffic should be allowed via security-group references, not broad CIDR rules

## Inputs

- `vpc_id`
- `admin_cidr`
- `name_prefix` (optional)

## Outputs

- `main_node_security_group_id`
- `sub_node_security_group_id`

## Ports included

- `22/tcp` from `admin_cidr`
- `6443/tcp` from sub nodes to main node
- `8472/udp` main<->main, main<->sub, sub<->sub
- `10250/tcp` main<->main, main<->sub, sub<->sub

## Notes

- This module is enough for initial private-network K3S validation.
- It is not the final security-group model for the 7-node topology.
- It does not include `80/443`, NodePort ranges, or HA etcd ports.
- It does not separate `app`, `metrics`, `logs-traces`, `db`, `llm-obs`, and `clickhouse` worker roles yet.
- If outbound is later restricted, add explicit egress rules for package install and cluster traffic.
