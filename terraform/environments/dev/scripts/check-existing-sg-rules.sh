#!/usr/bin/env bash

set -euo pipefail

query_json="$(cat)"

aws_region="$(printf '%s' "$query_json" | jq -r '.aws_region')"
admin_cidr="$(printf '%s' "$query_json" | jq -r '.admin_cidr')"
bastion_port="$(printf '%s' "$query_json" | jq -r '.bastion_port')"
bastion_sg_id="$(printf '%s' "$query_json" | jq -r '.bastion_sg_id')"
server_sg_id="$(printf '%s' "$query_json" | jq -r '.server_sg_id')"
worker_sg_id="$(printf '%s' "$query_json" | jq -r '.worker_sg_id')"

sg_json="$(
  aws ec2 describe-security-groups \
    --region "$aws_region" \
    --group-ids "$bastion_sg_id" "$server_sg_id" "$worker_sg_id" \
    --output json
)"

bastion_has_admin_ssh="$(
  printf '%s' "$sg_json" | jq -r \
    --arg sg "$bastion_sg_id" \
    --arg cidr "$admin_cidr" \
    --argjson port "$bastion_port" '
      any(
        .SecurityGroups[]
        | select(.GroupId == $sg)
        | .IpPermissions[]
        | select(.IpProtocol == "tcp" and .FromPort == $port and .ToPort == $port)
        | .IpRanges[]? 
        | .CidrIp == $cidr
      )
    '
)"

server_has_bastion_ssh="$(
  printf '%s' "$sg_json" | jq -r \
    --arg sg "$server_sg_id" \
    --arg source_sg "$bastion_sg_id" '
      any(
        .SecurityGroups[]
        | select(.GroupId == $sg)
        | .IpPermissions[]
        | select(.IpProtocol == "tcp" and .FromPort == 22 and .ToPort == 22)
        | .UserIdGroupPairs[]?
        | .GroupId == $source_sg
      )
    '
)"

worker_has_bastion_ssh="$(
  printf '%s' "$sg_json" | jq -r \
    --arg sg "$worker_sg_id" \
    --arg source_sg "$bastion_sg_id" '
      any(
        .SecurityGroups[]
        | select(.GroupId == $sg)
        | .IpPermissions[]
        | select(.IpProtocol == "tcp" and .FromPort == 22 and .ToPort == 22)
        | .UserIdGroupPairs[]?
        | .GroupId == $source_sg
      )
    '
)"

jq -n \
  --arg bastion_has_admin_ssh "$bastion_has_admin_ssh" \
  --arg server_has_bastion_ssh "$server_has_bastion_ssh" \
  --arg worker_has_bastion_ssh "$worker_has_bastion_ssh" \
  '{
    bastion_has_admin_ssh: $bastion_has_admin_ssh,
    server_has_bastion_ssh: $server_has_bastion_ssh,
    worker_has_bastion_ssh: $worker_has_bastion_ssh
  }'
