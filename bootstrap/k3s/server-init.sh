#!/usr/bin/env bash

set -euo pipefail

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required environment variable: $name" >&2
    exit 1
  fi
}

join_csv() {
  local csv="$1"
  local flag="$2"

  if [[ -z "$csv" ]]; then
    return
  fi

  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    printf ' %s %q' "$flag" "$item"
  done
}

require_env "K3S_TOKEN"
require_env "K3S_NODE_NAME"

readonly NODE_LABELS="${K3S_NODE_LABELS:-topology.k3s.io/role=server}"
readonly NODE_TAINTS="${K3S_NODE_TAINTS:-}"
readonly SERVER_ARGS="${K3S_SERVER_ARGS:-}"
readonly INSTALL_EXEC="server --node-name ${K3S_NODE_NAME}$(join_csv "$NODE_LABELS" "--node-label")$(join_csv "$NODE_TAINTS" "--node-taint") ${SERVER_ARGS}"

curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="${INSTALL_EXEC}" K3S_TOKEN="${K3S_TOKEN}" sh -
