# Evidence Artifacts

이 디렉터리는 Phase 2~7 실행 증거를 저장하는 기본 위치다.

## 기본 원칙

- 실행 결과는 가능하면 plain text 또는 JSON으로 저장한다.
- 민감값이 포함될 수 있는 파일은 redaction 후 저장한다.
- 실행 불가 항목은 실패 대신 `blocked` 상태로 남긴다.

## 권장 파일명

- `terragrunt-plan.txt`
- `terragrunt-output.json`
- `phase3-bastion-helper-check.txt`
- `phase3-kubectl-get-nodes.txt`
- `phase3-kubectl-get-nodes-labels.txt`
- `phase3-server-kubeconfig-check.txt`
- `phase4-monitoring-pods.txt`
- `phase5-sample-httpbin-curl.txt`
- `phase7-langfuse-pods.txt`
- `summary.md`

## 시작점

- summary 템플릿: [`summary-template.md`](/Users/len/Desktop/project/k8s/artifacts/evidence/summary-template.md)
- 증거 수집 스크립트: [`capture-phase-evidence.sh`](/Users/len/Desktop/project/k8s/scripts/capture-phase-evidence.sh)
