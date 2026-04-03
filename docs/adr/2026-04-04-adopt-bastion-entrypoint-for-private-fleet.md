# [ADR] private fleet 운영을 위한 bastion 진입점 채택

- **상태**: Accepted
- **날짜**: 2026-04-04

## 맥락 (Context)

학습 계정 기준 인프라는 private IP 중심으로 수렴했다.

- `server`, `app`, `metrics`, `logs_traces`, `db`, `llm_obs`, `clickhouse` 노드는 private IP 기반으로 운영한다
- Security Group은 수동 주입 경로를 포함해 private-only 운영을 기본으로 정리했다
- K3S bootstrap과 이후 운영 작업을 위해 외부에서 VPC 내부 노드로 들어갈 표준 진입 경계가 필요했다

직접 server에 공인 진입점을 부여하는 방식은 단순해 보이지만, 이후 모든 private 노드 접속 경계를 일관되게 설명하지 못한다.
또한 private 노드의 IP는 재생성 시 변경될 수 있으므로, 고정 IP 기반 접속 스크립트도 운영에 취약하다.

## 결정 (Decision)

private fleet 운영을 위한 표준 진입점으로 bastion host를 채택한다.

세부 결정은 다음과 같다.

1. bastion은 Terraform으로 관리한다
2. bastion만 public IP를 가진다
3. 나머지 K3S fleet는 private-only 운영을 기본으로 둔다
4. 운영/부트스트랩 경로는 `local/CloudShell -> bastion -> private nodes`로 고정한다
5. bastion 안의 접속 helper는 고정 private IP를 사용하지 않고, EC2 `Name` 태그로 최신 private IP를 조회한 뒤 SSH한다

이를 위해 bastion 관련 출력과 helper 스크립트를 함께 제공한다.

## 검토한 대안 (Alternatives Considered)

### 대안 1: server에 직접 공인 진입점 부여

- **장점**: 초기 bootstrap은 더 단순하다
- **단점**: 전체 private fleet 운영 경계가 일관되지 않고, 이후 worker/db/observability 노드 접속 모델을 따로 설계해야 한다
- **탈락 사유**: 단기 편의는 있지만 운영 기준선으로는 경계가 불명확하다

### 대안 2: bastion 없이 고정 private IP 기반 SSH 스크립트 사용

- **장점**: 구현이 단순하다
- **단점**: 노드 재생성이나 재할당 시 private IP 변경으로 즉시 깨진다
- **탈락 사유**: 운영 자동화 관점에서 취약하다

### 대안 3: SSM을 표준 진입점으로 채택

- **장점**: SSH와 IP 의존성을 더 줄일 수 있다
- **단점**: IAM, agent, 네트워크 경로를 추가로 정리해야 하며 현재 학습 계정 기준선에는 포함되지 않았다
- **탈락 사유**: 현재 단계에서 결정 범위를 불필요하게 넓힌다

## 결과 (Consequences)

### 긍정적

- private fleet 운영 경계가 하나의 진입점으로 정리된다
- K3S bootstrap, 운영 점검, kubeconfig 수집 경로를 같은 방식으로 설명할 수 있다
- 노드 private IP가 바뀌어도 `Name` 태그 기반 helper로 접속 경로를 유지할 수 있다

### 부정적

- bastion 1대의 추가 비용과 운영 포인트가 생긴다
- bastion host 자체의 보안과 SSH key 관리가 중요해진다

### 리스크

- bastion SG와 private node SG 간 SSH 규칙이 누락되면 운영 진입점이 막힌다
- EC2 `Name` 태그 규칙이 깨지면 helper 스크립트가 대상 노드를 찾지 못한다

### 완화책

- bastion SG와 `bastion -> server/worker:22` 규칙을 Terraform 계약에 포함한다
- helper 스크립트는 `Name = ${CLUSTER_PREFIX}-${NODE_NAME}` 규칙을 source of truth로 사용한다
- 문서와 입력 예시에 bastion을 기본 진입 경계로 명시한다

## 참고 (References)

- [루트 실행 가이드](../README.md)
- [Terragrunt 실행 가이드](../terragrunt/README.md)
- [학습 계정에서 수동 bootstrap SG 주입 경로 채택](./2026-04-03-adopt-manual-bootstrap-sg-in-learning-account.md)
