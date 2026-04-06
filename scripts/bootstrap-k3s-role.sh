#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: bootstrap-k3s-role.sh <server|agent> <node-name> <labels> [taints]
EOF
}

if [[ $# -lt 3 || $# -gt 4 ]]; then
  usage
  exit 1
fi

readonly MODE="$1"
readonly NODE_NAME="$2"
readonly NODE_LABELS="$3"
readonly NODE_TAINTS="${4:-}"

case "$MODE" in
  server)
    : "${K3S_TOKEN:?K3S_TOKEN is required}"
    K3S_NODE_NAME="$NODE_NAME" \
    K3S_NODE_LABELS="$NODE_LABELS" \
    K3S_NODE_TAINTS="$NODE_TAINTS" \
    bash bootstrap/k3s/server-init.sh
    ;;
  agent)
    : "${K3S_SERVER_HOST:?K3S_SERVER_HOST is required}"
    : "${K3S_TOKEN:?K3S_TOKEN is required}"
    K3S_SERVER_HOST="$K3S_SERVER_HOST" \
    K3S_TOKEN="$K3S_TOKEN" \
    K3S_NODE_NAME="$NODE_NAME" \
    K3S_NODE_LABELS="$NODE_LABELS" \
    K3S_NODE_TAINTS="$NODE_TAINTS" \
    bash bootstrap/k3s/agent-init.sh
    ;;
  *)
    usage
    exit 1
    ;;
esac
