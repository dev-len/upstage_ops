#!/usr/bin/env bash

set -euo pipefail

readonly EVIDENCE_DIR="${1:-artifacts/evidence}"
mkdir -p "$EVIDENCE_DIR"

if [[ -d /opt/k3s-bootstrap ]]; then
  ls -la /opt/k3s-bootstrap | tee "${EVIDENCE_DIR}/phase3-bastion-helper-check.txt"
else
  echo "missing /opt/k3s-bootstrap" | tee "${EVIDENCE_DIR}/phase3-bastion-helper-check.txt"
fi

if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
  echo "kubeconfig present: /etc/rancher/k3s/k3s.yaml" | tee "${EVIDENCE_DIR}/phase3-server-kubeconfig-check.txt"
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  kubectl get nodes -o wide | tee "${EVIDENCE_DIR}/phase3-kubectl-get-nodes.txt"
  kubectl get nodes --show-labels | tee "${EVIDENCE_DIR}/phase3-kubectl-get-nodes-labels.txt"
else
  echo "missing kubeconfig: /etc/rancher/k3s/k3s.yaml" | tee "${EVIDENCE_DIR}/phase3-server-kubeconfig-check.txt"
fi
