#!/usr/bin/env bash

set -euo pipefail

readonly EVIDENCE_DIR="${EVIDENCE_DIR:-artifacts/evidence}"
readonly HELM_TIMEOUT="${HELM_TIMEOUT:-15m}"
readonly KUBECTL_TIMEOUT="${KUBECTL_TIMEOUT:-300s}"

mkdir -p "$EVIDENCE_DIR"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required" >&2
    exit 1
  fi
}

require_secret() {
  local namespace="$1"
  local name="$2"

  kubectl get secret "$name" -n "$namespace" >/dev/null
}

capture_failure_context() {
  kubectl get pods -A -o wide >"${EVIDENCE_DIR}/phase5-pods.txt" 2>&1 || true
  kubectl get svc -A >"${EVIDENCE_DIR}/phase5-services.txt" 2>&1 || true
  kubectl get events -A --sort-by=.lastTimestamp >"${EVIDENCE_DIR}/phase5-events.txt" 2>&1 || true
}

run_helm_target() {
  local target="$1"
  local outfile="${EVIDENCE_DIR}/phase5-${target}-helm.txt"

  if ! HELM_TIMEOUT="$HELM_TIMEOUT" bash scripts/helm-rollout.sh "$target" >"$outfile" 2>&1; then
    capture_failure_context
    exit 1
  fi
}

require_cmd kubectl
require_cmd helm

require_secret monitoring grafana-admin-secret
require_secret langfuse langfuse-app-secret
require_secret langfuse langfuse-db-secret
require_secret langfuse langfuse-redis-secret
require_secret langfuse langfuse-clickhouse-secret

kubectl apply -k kubernetes/platform/observability >"${EVIDENCE_DIR}/phase5-observability-kustomize.txt"
kubectl apply -k kubernetes/platform/langfuse >"${EVIDENCE_DIR}/phase5-langfuse-kustomize.txt"
kubectl apply -k kubernetes/apps/sample-httpbin >"${EVIDENCE_DIR}/phase5-sample-httpbin-apply.txt"

run_helm_target prometheus
run_helm_target grafana
run_helm_target loki
run_helm_target tempo
run_helm_target otel-collector
run_helm_target langfuse

if ! kubectl rollout status deployment/sample-httpbin -n sample-app --timeout="$KUBECTL_TIMEOUT" \
  >"${EVIDENCE_DIR}/phase5-sample-httpbin-rollout.txt" 2>&1; then
  capture_failure_context
  exit 1
fi

kubectl get pods -A -o wide >"${EVIDENCE_DIR}/phase5-pods.txt"
kubectl get svc -A >"${EVIDENCE_DIR}/phase5-services.txt"
kubectl get ingress -A >"${EVIDENCE_DIR}/phase5-ingress.txt"
kubectl get events -A --sort-by=.lastTimestamp >"${EVIDENCE_DIR}/phase5-events.txt"
