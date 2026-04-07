#!/usr/bin/env bash

set -euo pipefail

readonly EVIDENCE_DIR="${EVIDENCE_DIR:-artifacts/evidence}"
readonly TG_DIR="${TG_DIR:-terragrunt/dev}"
readonly INPUTS_FILE="${INPUTS_FILE:-${TG_DIR}/inputs.hcl}"
readonly SSH_USER="${SSH_USER:-ubuntu}"
readonly SERVER_SSH_USER="${SERVER_SSH_USER:-ubuntu}"
readonly SSH_PORT="${SSH_PORT:-}"
readonly SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"
readonly READY_TIMEOUT_SECONDS="${READY_TIMEOUT_SECONDS:-1200}"
readonly POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-30}"

mkdir -p /tmp/.terragrunt-cache /tmp/.terraform-plugin-cache "$EVIDENCE_DIR"

export TG_DOWNLOAD_DIR="${TG_DOWNLOAD_DIR:-/tmp/.terragrunt-cache}"
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/.terraform-plugin-cache}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required in this environment" >&2
    exit 1
  fi
}

read_input_value() {
  local key="$1"
  local value

  value="$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"\\([^\"]*\\)\"[[:space:]]*$/\\1/p" "$INPUTS_FILE" | head -n 1)"
  if [[ -n "$value" ]]; then
    printf '%s\n' "$value"
    return
  fi

  value="$(sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\\([0-9][0-9]*\\)[[:space:]]*$/\\1/p" "$INPUTS_FILE" | head -n 1)"
  printf '%s\n' "$value"
}

terragrunt_output_json() {
  (
    cd "$TG_DIR"
    terragrunt output -json 2>/dev/null || printf '{}\n'
  )
}

assert_unique_line() {
  local label="$1"
  local value="$2"
  local count

  count="$(printf '%s\n' "$value" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [[ "$count" != "1" ]]; then
    echo "Expected exactly one ${label}, got ${count}" >&2
    exit 1
  fi
}

has_single_line() {
  local value="$1"
  local count

  count="$(printf '%s\n' "$value" | sed '/^$/d' | wc -l | tr -d ' ')"
  [[ "$count" == "1" ]]
}

collect_worker_diagnostics() {
  local node_map_json="$1"
  local node_lines="$2"
  local logical_name
  local private_ip
  local runtime_name

  while IFS=$'\t' read -r logical_name private_ip; do
    [[ -n "$logical_name" ]] || continue
    [[ "$logical_name" == "server" ]] && continue

    runtime_name="${logical_name//_/-}"
    if printf '%s\n' "$node_lines" | awk '{print $1" "$2}' | grep -Eq "^${runtime_name} Ready"; then
      continue
    fi

    run_bastion_node_command "$logical_name" "{
      echo '=== systemctl ===';
      sudo systemctl status k3s-agent --no-pager || true;
      echo;
      echo '=== journalctl ===';
      sudo journalctl -u k3s-agent -n 200 --no-pager || true;
      echo;
      echo '=== cloud-init-output ===';
      sudo tail -n 200 /var/log/cloud-init-output.log || true;
    }" >"${EVIDENCE_DIR}/worker-diagnostics-${logical_name}.txt" 2>&1 || true
  done < <(printf '%s\n' "$node_map_json" | jq -r 'to_entries[] | [.key, .value] | @tsv')
}

run_bastion_command() {
  local remote_command="$1"

  ssh "${ssh_base_args[@]}" -p "$EFFECTIVE_SSH_PORT" "$bastion_target" "$remote_command"
}

run_bastion_node_command() {
  local logical_name="$1"
  local remote_command="$2"
  local escaped_remote_command
  printf -v escaped_remote_command '%q' "$remote_command"

  run_bastion_command "AWS_REGION='${AWS_REGION}' CLUSTER_PREFIX='${CLUSTER_PREFIX}' /opt/k3s-bootstrap/connect-node.sh '${logical_name}' ${escaped_remote_command}"
}

require_cmd terragrunt
require_cmd jq
require_cmd ssh

if [[ -z "$SSH_IDENTITY_FILE" ]]; then
  echo "SSH_IDENTITY_FILE is required, for example: SSH_IDENTITY_FILE=~/.ssh/k3s-dev-key.pem" >&2
  exit 1
fi

if [[ ! -f "$SSH_IDENTITY_FILE" ]]; then
  echo "SSH identity file not found: ${SSH_IDENTITY_FILE}" >&2
  exit 1
fi

readonly AWS_REGION="${AWS_REGION:-$(read_input_value aws_region)}"
readonly CLUSTER_PREFIX="${CLUSTER_PREFIX:-$(read_input_value name_prefix)}"
effective_ssh_port="${SSH_PORT:-$(read_input_value bastion_ssh_port)}"
readonly EFFECTIVE_SSH_PORT="${effective_ssh_port:-22022}"

if [[ -z "$AWS_REGION" || -z "$CLUSTER_PREFIX" ]]; then
  echo "Failed to resolve aws_region or name_prefix from ${INPUTS_FILE}" >&2
  exit 1
fi

tg_output_json="$(terragrunt_output_json)"
printf '%s\n' "$tg_output_json" >"${EVIDENCE_DIR}/terragrunt-output.json"

output_bastion_ip="$(printf '%s\n' "$tg_output_json" | jq -r '.bastion_public_ip.value // empty')"
output_server_ip="$(printf '%s\n' "$tg_output_json" | jq -r '.k3s_server_private_ip.value // empty')"
output_node_map_json="$(printf '%s\n' "$tg_output_json" | jq -c '.k3s_private_ips_by_name.value // {}')"
resolved_bastion_ip="$output_bastion_ip"
resolved_server_ip="$output_server_ip"
resolved_node_map_json="$output_node_map_json"

if ! has_single_line "$resolved_bastion_ip" || ! has_single_line "$resolved_server_ip" || [[ "$resolved_node_map_json" == "{}" ]]; then
  require_cmd aws
  instances_json="$(
    aws ec2 describe-instances \
      --region "$AWS_REGION" \
      --filters \
        "Name=tag:Cluster,Values=${CLUSTER_PREFIX}" \
        "Name=instance-state-name,Values=running"
  )"
  printf '%s\n' "$instances_json" >"${EVIDENCE_DIR}/aws-describe-instances.json"

  aws_bastion_ip="$(
    printf '%s\n' "$instances_json" |
      jq -r '
        .Reservations[].Instances[]
        | select(.Tags // [] | any(.Key == "Role" and .Value == "bastion"))
        | .PublicIpAddress // empty
      '
  )"
  assert_unique_line "bastion public IP" "$aws_bastion_ip"
  aws_bastion_ip="$(printf '%s\n' "$aws_bastion_ip" | head -n 1)"

  aws_server_ip="$(
    printf '%s\n' "$instances_json" |
      jq -r '
        .Reservations[].Instances[]
        | select(.Tags // [] | any(.Key == "NodeName" and .Value == "server"))
        | .PrivateIpAddress // empty
      '
  )"
  assert_unique_line "server private IP" "$aws_server_ip"
  aws_server_ip="$(printf '%s\n' "$aws_server_ip" | head -n 1)"

  aws_node_map_json="$(
    printf '%s\n' "$instances_json" |
      jq -c '
        [
          .Reservations[].Instances[]
          | select(.Tags // [] | any(.Key == "NodeName"))
          | {
              key: ((.Tags // [] | map(select(.Key == "NodeName")) | .[0].Value)),
              value: .PrivateIpAddress
            }
        ]
        | sort_by(.key)
        | from_entries
      '
  )"

  if [[ "$aws_node_map_json" == "{}" ]]; then
    echo "Could not resolve node private IP map from AWS describe-instances" >&2
    exit 1
  fi

  resolved_bastion_ip="$aws_bastion_ip"
  resolved_server_ip="$aws_server_ip"
  resolved_node_map_json="$aws_node_map_json"
fi

readonly BASTION_PUBLIC_IP="$resolved_bastion_ip"
readonly SERVER_PRIVATE_IP="$resolved_server_ip"
readonly PRIVATE_IPS_BY_NAME_JSON="$resolved_node_map_json"
readonly EXPECTED_NODE_COUNT="$(printf '%s\n' "$PRIVATE_IPS_BY_NAME_JSON" | jq 'length')"

printf '%s\n' "$PRIVATE_IPS_BY_NAME_JSON" | jq -e '.server' >/dev/null

printf '%s\n' "$PRIVATE_IPS_BY_NAME_JSON" | jq -n \
  --arg bastion_public_ip "$BASTION_PUBLIC_IP" \
  --arg server_private_ip "$SERVER_PRIVATE_IP" \
  --argjson private_ips_by_name "$PRIVATE_IPS_BY_NAME_JSON" \
  '{
    bastion_public_ip: $bastion_public_ip,
    server_private_ip: $server_private_ip,
    private_ips_by_name: $private_ips_by_name
  }' >"${EVIDENCE_DIR}/resolved-instance-map.json"

ssh_base_args=(
  -i "$SSH_IDENTITY_FILE"
  -o StrictHostKeyChecking=no
  -o BatchMode=yes
)

bastion_target="${SSH_USER}@${BASTION_PUBLIC_IP}"

ssh "${ssh_base_args[@]}" -p "$EFFECTIVE_SSH_PORT" "$bastion_target" \
  "ls -la /opt/k3s-bootstrap" | tee "${EVIDENCE_DIR}/phase3-bastion-helper-check.txt"

run_bastion_node_command "server" "sudo systemctl is-active k3s" \
  | tee "${EVIDENCE_DIR}/phase3-k3s-service-status.txt"

run_bastion_node_command "server" \
  "sudo test -f /etc/rancher/k3s/k3s.yaml && echo kubeconfig present: /etc/rancher/k3s/k3s.yaml" \
  | tee "${EVIDENCE_DIR}/phase3-server-kubeconfig-check.txt"

ready_deadline=$((SECONDS + READY_TIMEOUT_SECONDS))
last_nodes_output=""
last_labels_output=""

while (( SECONDS < ready_deadline )); do
  last_nodes_output="$(
    run_bastion_node_command "server" "sudo k3s kubectl get nodes -o wide --no-headers" 2>/dev/null || true
  )"
  last_labels_output="$(
    run_bastion_node_command "server" "sudo k3s kubectl get nodes --show-labels --no-headers" 2>/dev/null || true
  )"

  printf '%s\n' "$last_nodes_output" >"${EVIDENCE_DIR}/phase3-kubectl-get-nodes.txt"
  printf '%s\n' "$last_labels_output" >"${EVIDENCE_DIR}/phase3-kubectl-get-nodes-labels.txt"

  ready_count="$(printf '%s\n' "$last_nodes_output" | awk 'NF > 0 && $2 ~ /^Ready/ { count++ } END { print count+0 }')"
  node_count="$(printf '%s\n' "$last_nodes_output" | awk 'NF > 0 { count++ } END { print count+0 }')"

  if [[ "$node_count" -eq "$EXPECTED_NODE_COUNT" && "$ready_count" -eq "$EXPECTED_NODE_COUNT" ]]; then
    printf 'expected_nodes=%s\ncurrent_nodes=%s\nready_nodes=%s\nstatus=ready\n' \
      "$EXPECTED_NODE_COUNT" "$node_count" "$ready_count" >"${EVIDENCE_DIR}/phase3-node-readiness-status.txt"
    cat <<EOF
Resolved bastion: ${BASTION_PUBLIC_IP}
Resolved server: ${SERVER_PRIVATE_IP}
Expected nodes: ${EXPECTED_NODE_COUNT}
Status: ready
Evidence written under: ${EVIDENCE_DIR}
EOF
    exit 0
  fi

  sleep "$POLL_INTERVAL_SECONDS"
done

printf 'expected_nodes=%s\ncurrent_nodes=%s\nready_nodes=%s\nstatus=timeout\n' \
  "$EXPECTED_NODE_COUNT" \
  "$(printf '%s\n' "$last_nodes_output" | awk 'NF > 0 { count++ } END { print count+0 }')" \
  "$(printf '%s\n' "$last_nodes_output" | awk 'NF > 0 && $2 ~ /^Ready/ { count++ } END { print count+0 }')" \
  >"${EVIDENCE_DIR}/phase3-node-readiness-status.txt"

collect_worker_diagnostics "$PRIVATE_IPS_BY_NAME_JSON" "$last_nodes_output"

echo "Timed out waiting for all K3S nodes to become Ready" >&2
exit 1
