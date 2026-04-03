#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <node-name> [ssh-command]" >&2
  exit 1
fi

readonly NODE_NAME="$1"
readonly REMOTE_COMMAND="${2:-}"
readonly AWS_REGION="${AWS_REGION:-us-east-1}"
readonly CLUSTER_PREFIX="${CLUSTER_PREFIX:-k3s-dev}"
readonly SSH_USER="${SSH_USER:-ubuntu}"
readonly SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"
readonly SSH_EXTRA_ARGS="${SSH_EXTRA_ARGS:-}"
readonly INSTANCE_NAME_TAG="${CLUSTER_PREFIX}-${NODE_NAME}"

PRIVATE_IP="$(
  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
      "Name=tag:Name,Values=${INSTANCE_NAME_TAG}" \
      "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].PrivateIpAddress | [0]' \
    --output text
)"

if [[ -z "$PRIVATE_IP" || "$PRIVATE_IP" == "None" ]]; then
  echo "could not find running instance for Name tag: ${INSTANCE_NAME_TAG}" >&2
  exit 1
fi

ssh_args=()
if [[ -n "$SSH_IDENTITY_FILE" ]]; then
  ssh_args+=("-i" "$SSH_IDENTITY_FILE")
fi

if [[ -n "$SSH_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_args=( $SSH_EXTRA_ARGS )
  ssh_args+=("${extra_args[@]}")
fi

if [[ -n "$REMOTE_COMMAND" ]]; then
  exec ssh "${ssh_args[@]}" "${SSH_USER}@${PRIVATE_IP}" "$REMOTE_COMMAND"
fi

exec ssh "${ssh_args[@]}" "${SSH_USER}@${PRIVATE_IP}"
