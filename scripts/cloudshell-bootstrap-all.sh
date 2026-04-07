#!/usr/bin/env bash

set -euo pipefail

readonly EVIDENCE_DIR="${EVIDENCE_DIR:-artifacts/evidence}"
readonly TG_DIR="${TG_DIR:-terragrunt/dev}"
readonly INPUTS_FILE="${INPUTS_FILE:-${TG_DIR}/inputs.hcl}"
readonly OBS_SECRET_FILE="${OBS_SECRET_FILE:-.cloudshell/secrets/observability.secret.yaml}"
readonly LANGFUSE_SECRET_FILE="${LANGFUSE_SECRET_FILE:-.cloudshell/secrets/langfuse.secret.yaml}"
readonly SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-}"
readonly SUMMARY_FILE="${EVIDENCE_DIR}/summary.md"
readonly STATUS_FILE="${EVIDENCE_DIR}/bootstrap-status.log"

mkdir -p /tmp/.terragrunt-cache /tmp/.terraform-plugin-cache "$EVIDENCE_DIR"

export TG_DOWNLOAD_DIR="${TG_DOWNLOAD_DIR:-/tmp/.terragrunt-cache}"
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/.terraform-plugin-cache}"

: >"$STATUS_FILE"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required" >&2
    exit 1
  fi
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "required file not found: $1" >&2
    exit 1
  fi
}

validate_secret_file() {
  local file="$1"
  shift
  local pairs=("$@")
  local pair
  local namespace
  local name

  require_file "$file"

  if grep -q 'CHANGE_ME' "$file"; then
    echo "placeholder value remains in ${file}" >&2
    exit 1
  fi

  for pair in "${pairs[@]}"; do
    namespace="${pair%%:*}"
    name="${pair##*:}"
    if ! grep -Eq "namespace:[[:space:]]*${namespace}" "$file"; then
      echo "expected namespace ${namespace} in ${file}" >&2
      exit 1
    fi
    if ! grep -Eq "name:[[:space:]]*${name}" "$file"; then
      echo "expected secret ${name} in ${file}" >&2
      exit 1
    fi
  done
}

record_status() {
  local step="$1"
  local state="$2"
  printf '%s\t%s\n' "$step" "$state" >>"$STATUS_FILE"
}

run_step() {
  local step="$1"
  shift

  record_status "$step" "start"
  if "$@"; then
    record_status "$step" "ok"
    return 0
  fi

  record_status "$step" "failed"
  return 1
}

write_summary() {
  {
    echo "# CloudShell One-Shot Summary"
    echo
    echo "- 실행 경로: CloudShell local state 기본"
    echo "- state 복구 전략: terragrunt output 우선, AWS tag 조회 fallback"
    echo "- EIP 사용 여부: false"
    echo
    echo "## Step Status"
    while IFS=$'\t' read -r step state; do
      printf -- "- `%s`: `%s`\n" "$step" "$state"
    done <"$STATUS_FILE"
  } >"$SUMMARY_FILE"
}

trap write_summary EXIT

require_cmd terraform
require_cmd terragrunt
require_cmd aws
require_cmd jq
require_cmd kubectl
require_cmd helm
require_cmd ssh
require_cmd bash

require_file "$INPUTS_FILE"

if [[ -z "$SSH_IDENTITY_FILE" ]]; then
  echo "SSH_IDENTITY_FILE is required" >&2
  exit 1
fi

require_file "$SSH_IDENTITY_FILE"

validate_secret_file "$OBS_SECRET_FILE" \
  "monitoring:grafana-admin-secret"
validate_secret_file "$LANGFUSE_SECRET_FILE" \
  "langfuse:langfuse-app-secret" \
  "langfuse:langfuse-db-secret" \
  "langfuse:langfuse-redis-secret" \
  "langfuse:langfuse-clickhouse-secret"

run_step "terragrunt-plan" bash scripts/cloudshell-plan.sh
run_step "terragrunt-apply" bash scripts/cloudshell-replace-apply.sh
run_step "k3s-readiness" env SSH_IDENTITY_FILE="$SSH_IDENTITY_FILE" bash scripts/cloudshell-k3s-check.sh
run_step "namespace-apply-observability" bash -lc "kubectl apply -f 'kubernetes/platform/observability/namespace.yaml' >'${EVIDENCE_DIR}/phase4-observability-namespace-apply.txt'"
run_step "namespace-apply-langfuse" bash -lc "kubectl apply -f 'kubernetes/platform/langfuse/namespace.yaml' >'${EVIDENCE_DIR}/phase4-langfuse-namespace-apply.txt'"
run_step "secret-apply-observability" bash -lc "kubectl apply -f '$OBS_SECRET_FILE' | tee '${EVIDENCE_DIR}/phase4-secrets-apply.txt'"
run_step "secret-apply-langfuse" bash -lc "kubectl apply -f '$LANGFUSE_SECRET_FILE' | tee -a '${EVIDENCE_DIR}/phase4-secrets-apply.txt'"
run_step "workload-rollout" bash scripts/cloudshell-workload-rollout.sh
run_step "bastion-wrapper-refresh" env SSH_IDENTITY_FILE="$SSH_IDENTITY_FILE" bash scripts/sync-bastion-wrappers.sh
