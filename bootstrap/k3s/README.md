# K3S Bootstrap

This directory contains the bootstrap assets for assembling the EC2 baseline nodes into a K3S cluster.

## Scope

- server install flow
- agent join flow
- node role labels
- optional taint strategy for infra-only nodes

Terraform provisions instances and outputs their addresses. These scripts do not provision AWS resources.

## Files

- `server-init.sh`
  - Installs the K3S server node
- `agent-init.sh`
  - Installs K3S agents and joins them to the server
- `../bastion/*`
  - Bastion-side helper scripts that resolve node IPs by EC2 tags before SSH

## Required inputs

### Server

- `K3S_TOKEN`
  - shared cluster join token
- `K3S_NODE_NAME`
  - logical node name, for example `server`
- `K3S_NODE_LABELS`
  - comma-separated labels for the server node
- `K3S_NODE_TAINTS`
  - optional comma-separated taints for the server node
- `K3S_SERVER_ARGS`
  - optional extra server arguments

### Agent

- `K3S_SERVER_HOST`
  - server private IP or DNS name
- `K3S_TOKEN`
  - shared cluster join token
- `K3S_NODE_NAME`
  - logical node name, for example `metrics-1`
- `K3S_NODE_LABELS`
  - comma-separated labels for the node role
- `K3S_NODE_TAINTS`
  - optional comma-separated taints for infra-dedicated nodes
- `K3S_AGENT_ARGS`
  - optional extra agent arguments

## Recommended labels

- server
  - `topology.k3s.io/role=server`
- app
  - `topology.k3s.io/role=app`
- metrics
  - `topology.k3s.io/role=metrics`
- logs-traces
  - `topology.k3s.io/role=logs-traces`
- db
  - `topology.k3s.io/role=db`
- llm-obs
  - `topology.k3s.io/role=llm-obs`
- clickhouse
  - `topology.k3s.io/role=clickhouse`

## Recommended taints

Keep the app nodes untainted and use taints only for infra-isolated roles when needed.

- metrics
  - `dedicated=metrics:NoSchedule`
- logs-traces
  - `dedicated=logs-traces:NoSchedule`
- db
  - `dedicated=db:NoSchedule`
- llm-obs
  - `dedicated=llm-obs:NoSchedule`
- clickhouse
  - `dedicated=clickhouse:NoSchedule`

## Join strategy

1. Provision the instances with Terraform.
2. Pick or generate one `K3S_TOKEN`.
3. Run `server-init.sh` on the server node.
4. Read the server private IP from Terraform outputs.
5. Run `agent-init.sh` on each worker node with the correct role labels and optional taints.

When node private IPs are unstable, prefer running the SSH hop from the bastion
host with the helper scripts in `../bastion/` instead of hardcoding IPs.

## Handoff to later lanes

- `T6` consumes the role labels and optional taints when placing observability and Langfuse workloads.
- `T8` can automate these scripts through CloudShell or a CI runner once execution ownership is decided.
