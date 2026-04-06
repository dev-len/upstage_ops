#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly OUTPUT_DIR="${1:-artifacts/evidence}"
readonly TEMPLATE_FILE="${REPO_ROOT}/artifacts/evidence/summary-template.md"

mkdir -p "$OUTPUT_DIR"

SUMMARY_FILE="${OUTPUT_DIR}/summary.md"

if [[ ! -f "$SUMMARY_FILE" ]]; then
  cp "$TEMPLATE_FILE" "$SUMMARY_FILE"
fi

capture() {
  local name="$1"
  shift

  if "$@" >"${OUTPUT_DIR}/${name}.txt" 2>&1; then
    echo "[ok] ${name} -> ${OUTPUT_DIR}/${name}.txt"
    return
  fi

  echo "[warn] ${name} failed, check ${OUTPUT_DIR}/${name}.txt" >&2
}

append_blocked() {
  local item="$1"
  local reason="$2"

  {
    echo "- 항목: ${item}"
    echo "  원인: ${reason}"
    echo "  다음 조치: 실행 환경 또는 권한을 준비한 뒤 재실행"
  } >>"${OUTPUT_DIR}/blocked.txt"
}

if command -v terragrunt >/dev/null 2>&1; then
  capture terragrunt-hclfmt terragrunt hclfmt --check
  capture terragrunt-validate sh -c "cd terragrunt/dev && terragrunt validate"
  capture terragrunt-output sh -c "cd terragrunt/dev && terragrunt output -json"
else
  printf 'blocked: terragrunt is not installed in this environment\n' >"${OUTPUT_DIR}/terragrunt.txt"
  append_blocked "terragrunt validate/output" "terragrunt 바이너리가 현재 환경에 없음"
fi

if command -v kubectl >/dev/null 2>&1; then
  capture kubectl-nodes kubectl get nodes -o wide
  capture kubectl-node-labels kubectl get nodes --show-labels
  capture kubectl-pods kubectl get pods -A -o wide
  capture kubectl-ingress kubectl get ingress -A
else
  printf 'blocked: kubectl is not installed in this environment\n' >"${OUTPUT_DIR}/kubectl.txt"
  append_blocked "kubectl cluster checks" "kubectl 바이너리가 현재 환경에 없음"
fi

for file in "${OUTPUT_DIR}"/kubectl-*.txt; do
  [[ -e "$file" ]] || continue
  if grep -q "Unable to connect to the server" "$file"; then
    append_blocked "$(basename "$file")" "현재 kubeconfig 또는 클러스터 연결이 준비되지 않음"
  fi
done

python3 - "$OUTPUT_DIR" <<'PY'
from pathlib import Path
import sys

out = Path(sys.argv[1])
summary = out / "summary.md"
blocked = out / "blocked.txt"

def has_text(name, needle):
    path = out / name
    return path.exists() and needle in path.read_text()

phase2_status = "blocked" if (out / "terragrunt.txt").exists() else "pending"
phase3_status = "blocked" if any(has_text(name, "Unable to connect to the server") for name in [
    "kubectl-nodes.txt",
    "kubectl-node-labels.txt",
]) else "pending"

blocked_text = blocked.read_text().rstrip() if blocked.exists() else "- 항목:\n  원인:\n  다음 조치:"

summary.write_text(
f"""# Execution Evidence Summary

- 작성일:
- 실행 환경:
- 실행자:

## Phase 2

- 상태: `{phase2_status}`
- 증거 파일:
  - terragrunt.txt
  - terragrunt-output.txt
- 비고:

## Phase 3

- 상태: `{phase3_status}`
- 증거 파일:
  - kubectl-nodes.txt
  - kubectl-node-labels.txt
- 비고:

## Phase 4

- 상태: `pending`
- 증거 파일:
- 비고:

## Phase 5

- 상태: `pending`
- 증거 파일:
- 비고:

## Phase 6

- 상태: `pending`
- 증거 파일:
  - docs/adr/007-document-envoy-ai-gateway-evaluation-boundary.md
- 비고:

## Phase 7

- 상태: `pending`
- 증거 파일:
- 비고:

## Blocked

{blocked_text}
"""
)
PY

cat <<EOF >"${OUTPUT_DIR}/index.txt"
Generated evidence files:
$(find "$OUTPUT_DIR" -maxdepth 1 -type f | sort)
EOF
