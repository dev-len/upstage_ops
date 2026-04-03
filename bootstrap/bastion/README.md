# Bastion Helpers

This directory contains helper scripts intended to run on the bastion host.

They do not hardcode private IP addresses. Instead, they resolve the latest
private IP for each node by querying EC2 with the instance `Name` tag.

## Files

- `connect-node.sh`
  - Generic resolver + SSH entrypoint
- `server.sh`
- `app_1.sh`
- `app_2.sh`
- `metrics.sh`
- `logs_traces.sh`
- `db.sh`
- `llm_obs.sh`
- `clickhouse.sh`

## Usage

Run from the bastion host with AWS credentials that can call
`ec2:DescribeInstances`.

Generic form:

```bash
./connect-node.sh server
./connect-node.sh db
```

Named helpers:

```bash
./server.sh
./db.sh
./clickhouse.sh
```

## Environment overrides

- `AWS_REGION`
  - defaults to `us-east-1`
- `CLUSTER_PREFIX`
  - defaults to `k3s-dev`
- `SSH_USER`
  - defaults to `ubuntu`
- `SSH_IDENTITY_FILE`
  - optional SSH identity file path
- `SSH_EXTRA_ARGS`
  - optional extra SSH arguments

## Notes

- The scripts only connect to instances in `running` state.
- Node discovery is based on the `Name` tag format `${CLUSTER_PREFIX}-${NODE_NAME}`.
- If the instance is recreated and its private IP changes, the script still works
  as long as the `Name` tag stays consistent.
