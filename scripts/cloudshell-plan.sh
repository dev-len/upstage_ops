#!/usr/bin/env bash

set -euo pipefail

readonly EVIDENCE_DIR="${EVIDENCE_DIR:-artifacts/evidence}"
readonly TG_DIR="${TG_DIR:-terragrunt/dev}"

mkdir -p /tmp/.terragrunt-cache /tmp/.terraform-plugin-cache "$EVIDENCE_DIR"

export TG_DOWNLOAD_DIR="${TG_DOWNLOAD_DIR:-/tmp/.terragrunt-cache}"
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-/tmp/.terraform-plugin-cache}"

cd "$TG_DIR"

terragrunt plan -no-color | tee "../../${EVIDENCE_DIR}/terragrunt-plan.txt"
terragrunt output -json | tee "../../${EVIDENCE_DIR}/terragrunt-output.json"
