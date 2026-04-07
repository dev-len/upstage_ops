#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: helm-rollout.sh <grafana|prometheus|loki|tempo|otel-collector|langfuse>
EOF
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

readonly TARGET="$1"
readonly HELM_TIMEOUT="${HELM_TIMEOUT:-15m}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required" >&2
    exit 1
  fi
}

require_cmd helm

case "$TARGET" in
  grafana)
    readonly RELEASE_NAME="grafana"
    readonly TARGET_NAMESPACE="monitoring"
    readonly REPO_NAME="grafana"
    readonly REPO_URL="https://grafana.github.io/helm-charts"
    readonly CHART_NAME="grafana/grafana"
    readonly CHART_VERSION="8.5.8"
    readonly VALUES_FILE="kubernetes/platform/observability/values/grafana-values.yaml"
    ;;
  prometheus)
    readonly RELEASE_NAME="prometheus"
    readonly TARGET_NAMESPACE="monitoring"
    readonly REPO_NAME="prometheus-community"
    readonly REPO_URL="https://prometheus-community.github.io/helm-charts"
    readonly CHART_NAME="prometheus-community/prometheus"
    readonly CHART_VERSION="25.30.0"
    readonly VALUES_FILE="kubernetes/platform/observability/values/prometheus-values.yaml"
    ;;
  loki)
    readonly RELEASE_NAME="loki"
    readonly TARGET_NAMESPACE="monitoring"
    readonly REPO_NAME="grafana"
    readonly REPO_URL="https://grafana.github.io/helm-charts"
    readonly CHART_NAME="grafana/loki"
    readonly CHART_VERSION="6.24.0"
    readonly VALUES_FILE="kubernetes/platform/observability/values/loki-values.yaml"
    ;;
  tempo)
    readonly RELEASE_NAME="tempo"
    readonly TARGET_NAMESPACE="monitoring"
    readonly REPO_NAME="grafana"
    readonly REPO_URL="https://grafana.github.io/helm-charts"
    readonly CHART_NAME="grafana/tempo"
    readonly CHART_VERSION="1.10.3"
    readonly VALUES_FILE="kubernetes/platform/observability/values/tempo-values.yaml"
    ;;
  otel-collector)
    readonly RELEASE_NAME="otel-collector"
    readonly TARGET_NAMESPACE="monitoring"
    readonly REPO_NAME="open-telemetry"
    readonly REPO_URL="https://open-telemetry.github.io/opentelemetry-helm-charts"
    readonly CHART_NAME="open-telemetry/opentelemetry-collector"
    readonly CHART_VERSION="0.91.1"
    readonly VALUES_FILE="kubernetes/platform/observability/values/otel-collector-values.yaml"
    ;;
  langfuse)
    readonly RELEASE_NAME="langfuse"
    readonly TARGET_NAMESPACE="langfuse"
    readonly REPO_NAME="langfuse"
    readonly REPO_URL="https://langfuse.github.io/langfuse-k8s"
    readonly CHART_NAME="langfuse/langfuse"
    readonly CHART_VERSION="1.4.0"
    readonly VALUES_FILE="kubernetes/platform/langfuse/values/langfuse-values.yaml"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [[ ! -f "$VALUES_FILE" ]]; then
  echo "values file not found: ${VALUES_FILE}" >&2
  exit 1
fi

helm repo add "$REPO_NAME" "$REPO_URL" --force-update >/dev/null
helm repo update "$REPO_NAME" >/dev/null

helm upgrade --install "$RELEASE_NAME" "$CHART_NAME" \
  --namespace "$TARGET_NAMESPACE" \
  --create-namespace \
  --values "$VALUES_FILE" \
  --version "$CHART_VERSION" \
  --wait \
  --timeout "$HELM_TIMEOUT"
