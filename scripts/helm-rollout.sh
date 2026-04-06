#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: helm-rollout.sh <observability|langfuse> <release-name> [namespace]
EOF
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 1
fi

readonly TARGET="$1"
readonly RELEASE_NAME="$2"
readonly NAMESPACE="${3:-}"

case "$TARGET" in
  observability)
    readonly TARGET_NAMESPACE="${NAMESPACE:-monitoring}"
    readonly VALUES_DIR="kubernetes/platform/observability/values"
    ;;
  langfuse)
    readonly TARGET_NAMESPACE="${NAMESPACE:-langfuse}"
    readonly VALUES_DIR="kubernetes/platform/langfuse/values"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if ! command -v helm >/dev/null 2>&1; then
  echo "helm is required" >&2
  exit 1
fi

echo "target=${TARGET}"
echo "release=${RELEASE_NAME}"
echo "namespace=${TARGET_NAMESPACE}"
echo "values_dir=${VALUES_DIR}"
echo
echo "Use the values files in ${VALUES_DIR} when running helm upgrade --install."
echo "This helper standardizes the repo path contract and leaves chart choice to the operator."
