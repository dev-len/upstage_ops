#!/usr/bin/env bash

set -euo pipefail

readonly TG_DIR="${TG_DIR:-terragrunt/dev}"
readonly OUTPUT_JSON="${OUTPUT_JSON:-artifacts/evidence/terragrunt-output.json}"
readonly REMOTE_BIN_DIR="${REMOTE_BIN_DIR:-~/bin}"
readonly SSH_USER="${SSH_USER:-ubuntu}"
readonly SSH_PORT="${SSH_PORT:-22022}"
readonly SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"
readonly SSH_EXTRA_ARGS="${SSH_EXTRA_ARGS:-}"

usage() {
  cat <<'EOF' >&2
usage: sync-bastion-wrappers.sh

Required:
  - terragrunt output JSON must exist or terragrunt must be available
  - bastion access must work via SSH

Optional env:
  OUTPUT_JSON=/path/to/terragrunt-output.json
  TG_DIR=terragrunt/dev
  SSH_USER=ubuntu
  SSH_PORT=22022
  SSH_IDENTITY_FILE=~/.ssh/k3s-dev-key.pem
  SSH_EXTRA_ARGS="-o StrictHostKeyChecking=no"
  REMOTE_BIN_DIR=~/bin
EOF
}

ssh_args=()
ssh_args+=("-p" "$SSH_PORT")

if [[ -n "$SSH_IDENTITY_FILE" ]]; then
  ssh_args+=("-i" "$SSH_IDENTITY_FILE")
fi

if [[ -n "$SSH_EXTRA_ARGS" ]]; then
  # shellcheck disable=SC2206
  extra_args=( $SSH_EXTRA_ARGS )
  ssh_args+=("${extra_args[@]}")
fi

if [[ ! -f "$OUTPUT_JSON" ]]; then
  if ! command -v terragrunt >/dev/null 2>&1; then
    usage
    echo "missing terragrunt output JSON and terragrunt is not installed" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$OUTPUT_JSON")"
  (
    cd "$TG_DIR"
    terragrunt output -json > "../../${OUTPUT_JSON}"
  )
fi

readonly BASTION_PUBLIC_IP="$(jq -r '.bastion_public_ip.value' "$OUTPUT_JSON")"

if [[ -z "$BASTION_PUBLIC_IP" || "$BASTION_PUBLIC_IP" == "null" ]]; then
  echo "bastion_public_ip missing from ${OUTPUT_JSON}" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

jq -r '.k3s_private_ips_by_name.value | keys[]' "$OUTPUT_JSON" |
while IFS= read -r logical_name; do
  runtime_name="${logical_name//_/-}"

  cat >"${tmp_dir}/${logical_name}.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec /opt/k3s-bootstrap/connect-node.sh ${logical_name} "\$@"
EOF
  chmod +x "${tmp_dir}/${logical_name}.sh"

  if [[ "$runtime_name" != "$logical_name" ]]; then
    cp "${tmp_dir}/${logical_name}.sh" "${tmp_dir}/${runtime_name}.sh"
    chmod +x "${tmp_dir}/${runtime_name}.sh"
  fi
done

cat >"${tmp_dir}/README.txt" <<EOF
Generated from ${OUTPUT_JSON}
Bastion target: ${BASTION_PUBLIC_IP}
Scripts:
$(find "$tmp_dir" -maxdepth 1 -type f -name '*.sh' -exec basename {} \; | sort)
EOF

ssh "${ssh_args[@]}" "${SSH_USER}@${BASTION_PUBLIC_IP}" "mkdir -p ${REMOTE_BIN_DIR}"
scp "${ssh_args[@]}" "${tmp_dir}"/*.sh "${tmp_dir}/README.txt" "${SSH_USER}@${BASTION_PUBLIC_IP}:${REMOTE_BIN_DIR}/"
ssh "${ssh_args[@]}" "${SSH_USER}@${BASTION_PUBLIC_IP}" "chmod +x ${REMOTE_BIN_DIR}/*.sh"

echo "synced wrappers to ${SSH_USER}@${BASTION_PUBLIC_IP}:${REMOTE_BIN_DIR}"
