#!/usr/bin/env bash

set -euo pipefail

readonly EVIDENCE_DIR="${EVIDENCE_DIR:-artifacts/evidence}"
readonly TG_DIR="${TG_DIR:-terragrunt/dev}"

mkdir -p /tmp/.terragrunt-cache /tmp/.terraform-plugin-cache "$EVIDENCE_DIR"

export TG_DOWNLOAD_DIR="${TG_DOWNLOAD_DIR:-/tmp/.terragrunt-cache}"
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/.terraform-plugin-cache}"

cd "$TG_DIR"

terragrunt apply \
  -replace='aws_instance.bastion[0]' \
  -replace='module.k3s_nodes.aws_instance.node["server"]' \
  -replace='module.k3s_nodes.aws_instance.node["app_1"]' \
  -replace='module.k3s_nodes.aws_instance.node["app_2"]' \
  -replace='module.k3s_nodes.aws_instance.node["metrics"]' \
  -replace='module.k3s_nodes.aws_instance.node["logs_traces"]' \
  -replace='module.k3s_nodes.aws_instance.node["db"]' \
  -replace='module.k3s_nodes.aws_instance.node["llm_obs"]' \
  -replace='module.k3s_nodes.aws_instance.node["clickhouse"]' | tee "../../${EVIDENCE_DIR}/terragrunt-apply.txt"

terragrunt output -json | tee "../../${EVIDENCE_DIR}/terragrunt-output.json"
