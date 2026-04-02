# security-groups module

This module creates the minimum AWS security groups required for a two-tier K3S layout:

- `main_node`: K3S server/control plane
- `sub_node`: K3S agent/worker nodes

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
- It does not include `80/443`, NodePort ranges, or HA etcd ports.
- If outbound is later restricted, add explicit egress rules for package install and cluster traffic.

