# CloudShell One-Shot Bootstrap

- 문서 상태: Draft
- 작성일: 2026-04-07
- 목적: CloudShell에서 스크립트 한 번으로 인프라 생성부터 K3S/workload 검증까지 수행하는 표준 실행 경로를 고정한다.

## 1. 실행 원칙

- CloudShell이 표준 실행면이다.
- EIP는 사용하지 않으므로 IP는 매 실행마다 다시 해석한다.
- 실제 Secret은 CloudShell 로컬 YAML 파일에서만 읽는다.
- worker 전체가 `Ready`가 아니면 workload 단계로 진행하지 않는다.

## 2. 입력 준비

필수:

- `terragrunt/dev/inputs.hcl`
- `.cloudshell/secrets/observability.secret.yaml`
- `.cloudshell/secrets/langfuse.secret.yaml`
- `SSH_IDENTITY_FILE`

Secret 파일 계약은 [secret-supply-contract.md](/Users/len/Desktop/project/k8s/docs/runbooks/secret-supply-contract.md)를 따른다.
특히 Langfuse Secret의 `host`는 EC2 주소가 아니라 K3S 내부 저장소 Service DNS를 넣는 계약이다.

## 3. 실행 순서

repo root 기준:

```bash
SSH_IDENTITY_FILE=~/.ssh/k3s-dev-key.pem bash scripts/cloudshell-bootstrap-all.sh
```

one-shot은 아래를 수행한다.

1. prerequisite와 입력 파일을 검증한다.
2. `terragrunt plan`을 실행한다.
3. bastion + 전체 node를 replace apply 한다.
4. 최신 output/AWS 조회로 bastion/server/node IP를 재해석한다.
5. K3S 전체 node `Ready`를 최대 20분 동안 확인한다.
6. Langfuse가 의존하는 저장소 계층(PostgreSQL, Redis, ClickHouse)의 Service 계약이 준비되어 있는지 확인한다.
7. Secret을 적용한다.
8. platform/app manifests를 적용하면서 Langfuse 저장소 `StatefulSet`을 생성한다.
9. Langfuse 저장소 `StatefulSet`이 `Ready`가 될 때까지 대기한 뒤 observability/Langfuse chart를 배포한다.
10. sample app rollout을 확인한다.
11. bastion wrapper와 evidence summary를 갱신한다.

## 4. state 전략

- 기본값은 CloudShell local state다.
- local state는 CloudShell 세션과 `/tmp` cache에 의존하므로 영구 보존을 가정하지 않는다.
- 세션이 끊기거나 local state가 사라져도 one-shot은 `terragrunt output` 대신 AWS tag 조회로 현재 인스턴스를 다시 찾을 수 있어야 한다.
- remote backend는 IAM/학습 계정 제약이 해소된 이후 선택적 경로로만 문서화한다.

## 5. 예외 처리

- `terragrunt output`이 비어 있으면 AWS tag 조회로 fallback 한다.
- tag 조회 결과가 0개 또는 2개 이상이면 중단한다.
- Secret 파일 누락, `CHANGE_ME` 잔존, namespace/name mismatch면 중단한다.
- Langfuse 저장소 Service 계약이 없으면 `host`를 채워도 Langfuse rollout은 성공할 수 없으므로, Secret 입력 전에 저장소 계층 준비 여부를 먼저 확인해야 한다.
- worker 일부가 `Ready`가 아니면 진단 파일을 저장하고 workload 단계로 가지 않는다.
- Helm release가 timeout 또는 실패하면 관련 pod/events/status evidence를 남기고 중단한다.

## 6. evidence

최소 evidence:

- `terragrunt-plan.txt`
- `terragrunt-apply.txt`
- `terragrunt-output.json`
- `resolved-instance-map.json`
- `phase3-kubectl-get-nodes.txt`
- `phase3-kubectl-get-nodes-labels.txt`
- `worker-diagnostics-*.txt`
- `phase4-secrets-apply.txt`
- `phase5-*.txt`
- `summary.md`
