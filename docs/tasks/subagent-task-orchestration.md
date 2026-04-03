# Subagent Task Orchestration

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: 전체 인프라 작업을 subagent 병렬 실행 단위로 분해하고, 각 task별 skill, 방향성, 입력/출력, 완료 기준을 고정한다.
- 관련 문서:
  - [README](/Users/len/Desktop/project/k8s/docs/tasks/README.md)
  - [PRD](/Users/len/Desktop/project/k8s/docs/PRD.md)
  - [아키텍처](/Users/len/Desktop/project/k8s/docs/architecture.md)
  - [네트워크 인벤토리](/Users/len/Desktop/project/k8s/docs/network-inventory.md)
  - [Security Group 포트 매트릭스](/Users/len/Desktop/project/k8s/docs/security-group-matrix.md)
  - [ADR-006](/Users/len/Desktop/project/k8s/docs/adr/006-adopt-k3s-seven-node-topology.md)

## 1. 공통 방향성

이 문서는 "지금 바로 subagent에 할당 가능한 작업 단위"를 정의한다. 구현 방향은 아래 원칙으로 고정한다.

- 기본 VPC와 기존 서브넷을 재사용한다.
- Terraform/Terragrunt는 기존 네트워크를 입력으로 받는 구조로 간다.
- 최종 목표는 7노드 K3S 역할 분리 토폴로지다.
- 초기 부트스트랩은 `server + worker-shared` Security Group 모델로 시작한다.
- `80/443` 공개, 역할별 Security Group 세분화, 데이터 계층 최소 노출은 후속 확장으로 둔다.
- AWS CloudShell 실행 제약을 고려해 모듈/환경 계층을 명확히 나눈다.
- 각 task는 가능한 한 독립적으로 진행하되, 공통 인터페이스를 문서 기준으로 먼저 맞춘다.
- 전체 lane 분해와 dispatch 준비에는 로컬 skill `parallel-infra-orchestrator`를 기본 orchestration skill로 사용한다.

## 2. 병렬 실행 규칙

### 2.1 공통 규칙

- 모든 subagent는 이 문서와 관련 ADR/PRD를 우선 기준으로 사용한다.
- 새 의사결정을 만들지 않는다. 미결정 항목을 구현으로 넘기지 말고 상위로 에스컬레이션한다.
- 각 task는 지정된 산출물과 완료 기준을 만족해야만 완료로 간주한다.
- 다른 lane의 변경을 되돌리지 않는다.
- 파일 경계가 겹치면 먼저 인터페이스 문서부터 합의하고 구현 순서를 조정한다.

### 2.2 병렬 그룹

아래처럼 나눈다.

- Group A: `T1`, `T2`, `T7`
  - Terraform 기반 계층, 네트워크 보안, 문서/검증 기준
- Group B: `T3`, `T4`
  - EC2 노드 구성, 스토리지 계층
- Group C: `T5`, `T6`
  - K3S bootstrap, 관측/LLM 워크로드 배치
- Group D: `T8`
  - CI/CD 및 운영 자동화

의존성은 다음 순서를 따른다.

- `T1 -> T3 -> T5`
- `T2 -> T3`
- `T3 -> T4`
- `T5 -> T6`
- `T1`, `T2`, `T3`, `T4`, `T5`, `T6` 진행 중에도 `T7`은 병렬 가능
- `T8`은 `T1`, `T3`, `T5`의 인터페이스가 고정된 후 진행

### 2.3 Worktree 실행 규칙

- 병렬 lane은 가능하면 각자 별도 git worktree에서 작업한다.
- worktree는 lane 단위로 하나씩 만든다.
- lane별 브랜치명은 `task/<task-id>-<slug>` 형식을 사용한다.
- subagent는 자기 worktree만 수정하고, 다른 worktree 변경을 기준으로 되돌리거나 재정렬하지 않는다.
- 아직 `main`에만 존재하는 미커밋 task 문서가 있으면, 상위 orchestrator가 brief를 프롬프트에 포함해 전달한다.
- 공통 인터페이스 문서 변경이 필요한 lane은 먼저 상위 orchestrator와 충돌 가능성을 확인한다.

## 3. Task Matrix

| ID | Task | 목표 | 권장 Skill | 권장 Role | 병렬 여부 |
|----|------|------|------------|-----------|-----------|
| `T1` | Terraform/Terragrunt 기반 계층 정리 | 실행 진입점과 환경 계층 표준화 | `terraform-skill`, `terragrunt-bootstrap` | `executor` | 병렬 시작 가능 |
| `T2` | SG 부트스트랩 정리 | 현재 보안그룹 모듈 완성도 보강 | `terraform-skill` | `executor` | 병렬 시작 가능 |
| `T3` | 7노드 EC2 기본형 | 역할별 노드 정의와 출력 구조 확정 | `terraform-skill` | `executor` | `T1`,`T2` 일부 의존 |
| `T4` | EBS/스토리지 레이어 | DB/LLM/ClickHouse 스토리지 정의 | `terraform-skill` | `executor` | `T3` 이후 |
| `T5` | K3S bootstrap 자동화 | server/agent 초기화 구조 작성 | `kubernetes-specialist` | `executor` | `T3` 이후 |
| `T6` | Observability + Langfuse 배치 | 앱/관측/LLM 계층 쿠버네티스 배치 구조 작성 | `kubernetes-specialist`, `k3s-observability-lane` | `executor` | `T5` 이후 |
| `T7` | 검증/보안/문서 기준선 | 테스트, 보안 스캔, 운영 문서 기준 고정 | `terraform-skill`, `security-review`, `code-review` | `writer` 또는 `verifier` | 병렬 시작 가능 |
| `T8` | CI/CD 및 운영 파이프라인 | CloudShell/GitHub Actions 기준 실행 경로 작성 | `terraform-skill`, `cloudshell-iac-pipeline` | `executor` | 후행 |

## 3.1 Task별 최종 skill 결정

- `T1`
  - 기본: `parallel-infra-orchestrator`, `terraform-skill`, `terragrunt-bootstrap`
  - 이유: lane 인터페이스 정렬 + Terragrunt 계층 설계
- `T2`
  - 기본: `parallel-infra-orchestrator`, `terraform-skill`
  - 이유: SG 부트스트랩은 Terraform 중심이며 별도 외부 skill 이점이 작다
- `T3`
  - 기본: `parallel-infra-orchestrator`, `terraform-skill`
  - 이유: 7노드 EC2 모델링은 Terraform resource/module 설계가 핵심
- `T4`
  - 기본: `parallel-infra-orchestrator`, `terraform-skill`
  - 이유: EBS/attachment 설계는 Terraform lane 내부로 유지
- `T5`
  - 기본: `parallel-infra-orchestrator`, `kubernetes-specialist`
  - 이유: K3S bootstrap 흐름과 role label/taint 설계가 핵심
- `T6`
  - 기본: `parallel-infra-orchestrator`, `kubernetes-specialist`, `k3s-observability-lane`
  - 이유: observability/Langfuse 배치는 Kubernetes와 repo-specific observability 제약을 같이 반영해야 한다
- `T7`
  - 기본: `parallel-infra-orchestrator`, `terraform-skill`, `security-review`, `code-review`
  - 이유: 검증 기준은 IaC + 보안 + 리뷰 체크를 함께 묶어야 한다
- `T8`
  - 기본: `parallel-infra-orchestrator`, `terraform-skill`, `cloudshell-iac-pipeline`
  - 이유: CloudShell 실행 제약과 GitHub Actions 경계를 함께 다뤄야 한다

## 4. Task Specifications

### T1. Terraform/Terragrunt 기반 계층 정리

- 목적:
  - Terraform 재사용 모듈과 Terragrunt 환경 진입점을 분리한다.
  - CloudShell에서 반복 실행 가능한 구조를 만든다.
- 방향성:
  - `modules/`는 재사용 모듈만 둔다.
  - 환경별 값은 Terragrunt inputs 또는 `tfvars` 예시로 관리한다.
  - 기존 네트워크 리소스는 생성 대상이 아니라 입력값이다.
- 권장 skill:
  - `terraform-skill`
  - `terragrunt-bootstrap`
- 권장 subagent role:
  - `executor`
- 주요 파일:
  - `terraform/`
  - `terragrunt.hcl`
  - `terragrunt/*`
- 입력:
  - `vpc_id`
  - `subnet_ids_by_az`
  - `aws_region`
  - `name_prefix`
- 출력:
  - `dev` 환경 실행 경로
  - 환경별 입력 구조
  - 공통 backend/provider/version 기준
- 완료 기준:
  - Terragrunt가 Terraform 루트 모듈을 일관되게 호출한다.
  - `dev` 환경에 필요한 입력 항목이 누락 없이 문서화된다.
  - 환경 구조만 보고 어떤 계층에서 무엇을 수정해야 하는지 명확하다.
- handoff to next:
  - `T3`는 이 계층을 통해 EC2 모듈을 연결한다.
  - `T8`은 이 실행 경로를 CI/CD에서 재사용한다.

### T2. SG 부트스트랩 정리

- 목적:
  - 현재 `main_node/sub_node` 구현을 실제 `server + worker-shared` 부트스트랩 의미로 정리한다.
- 방향성:
  - 초기 모델은 `server + worker-shared` 유지
  - SSH, K3S API, Flannel, Kubelet만 포함
  - `80/443`, DB 포트, 역할별 SG는 포함하지 않는다
- 권장 skill:
  - `terraform-skill`
- 권장 subagent role:
  - `executor`
- 주요 파일:
  - `terraform/modules/security-groups/*`
  - `terraform/environments/dev/*`
- 입력:
  - `vpc_id`
  - `admin_cidr`
  - `name_prefix`
- 출력:
  - SG IDs
  - 규칙 설명 문서
- 완료 기준:
  - 변수 검증과 설명이 보강된다.
  - 현재 부트스트랩 포트 범위가 문서와 코드에서 일치한다.
  - 이름과 출력이 server/worker 의미를 잘 드러낸다.
- handoff to next:
  - `T3`가 EC2 노드에 이 SG를 연결한다.

### T3. 7노드 EC2 기본형

- 목적:
  - 7노드 기준 역할별 EC2 배치를 Terraform으로 모델링한다.
- 방향성:
  - 초기 SG는 `server + worker-shared`
  - 단일 AZ 배치를 기본값으로 둔다
  - AMI, key pair, public IP, root volume 크기는 입력값으로 노출한다
  - K3S 설치까지 한 번에 넣지 말고, 노드 정의와 출력 안정화를 우선한다
- 권장 skill:
  - `terraform-skill`
- 권장 subagent role:
  - `executor`
- 주요 파일:
  - `terraform/modules/ec2-k3s-nodes/*`
  - `terraform/environments/dev/*`
- 입력:
  - `subnet_id` 또는 `subnet_ids_by_az`
  - `key_name`
  - `instance_type`
  - `node_definitions`
  - `server_security_group_id`
  - `worker_security_group_id`
- 출력:
  - instance IDs
  - private/public IPs
  - role별 노드 맵
  - K3S bootstrap에 필요한 server endpoint 정보
- 완료 기준:
  - 7노드 역할 구성이 코드상에서 명확히 표현된다.
  - 노드별 태그와 이름 규칙이 일관된다.
  - 후속 bootstrap 자동화가 가능한 수준의 출력이 제공된다.
- handoff to next:
  - `T4`, `T5`, `T8`

### T4. EBS/스토리지 레이어

- 목적:
  - 영속 스토리지가 필요한 역할에 대해 EBS 계층을 정의한다.
- 방향성:
  - 대상은 우선 `db`, `llm-obs`, `clickhouse`
  - 볼륨 생성과 attachment를 역할 기준으로 연결한다
  - 파일시스템 초기화나 마운트 스크립트는 bootstrap과 경계를 분리한다
- 권장 skill:
  - `terraform-skill`
- 권장 subagent role:
  - `executor`
- 주요 파일:
  - `terraform/modules/storage/*`
  - `terraform/environments/dev/*`
- 입력:
  - 역할별 volume size/type
  - 대상 instance ID
  - AZ
- 출력:
  - volume IDs
  - attachment 정보
- 완료 기준:
  - 영속 스토리지 대상 역할이 코드로 분리된다.
  - AZ/instance 연계 오류가 없도록 인터페이스가 단순하다.
- handoff to next:
  - `T5`, `T6`

### T5. K3S bootstrap 자동화

- 목적:
  - EC2 노드가 server/agent 역할에 맞게 K3S 클러스터로 조립되도록 bootstrap 흐름을 만든다.
- 방향성:
  - server 1대, agent N대 구조
  - 역할 라벨/taint를 7노드 기준으로 부여할 수 있어야 한다
  - Terraform과 쿠버네티스 매니페스트를 한 파일에 섞지 않는다
- 권장 skill:
  - `kubernetes-specialist`
- 권장 subagent role:
  - `executor`
- 주요 산출물:
  - cloud-init 또는 bootstrap script
  - K3S join/token 전달 방식
  - node label/taint 정책
- 입력:
  - server private IP
  - join token 또는 전달 방식
  - 역할별 노드 목록
- 출력:
  - 클러스터 bootstrap 절차
  - 역할별 라벨링 규칙
- 완료 기준:
  - 7노드 역할 분리를 위한 node labeling 전략이 문서/스크립트에 반영된다.
  - bootstrap 책임과 Terraform 책임이 분리된다.
- handoff to next:
  - `T6`, `T8`

### T6. Observability + Langfuse 배치

- 목적:
  - K3S 위에 observability 스택과 Langfuse 스택을 역할별 노드에 올릴 준비를 한다.
- 방향성:
  - Metrics, Logs, Traces, Langfuse 저장소 경계를 유지한다
  - nodeSelector, affinity, toleration을 활용해 역할별 워크로드를 분리한다
  - 일반 앱 경로와 LLM observability 경로를 혼동하지 않는다
- 권장 skill:
  - `kubernetes-specialist`
- 권장 subagent role:
  - `executor`
- 주요 산출물:
  - Helm values 또는 Kubernetes manifests
  - 역할별 scheduling 규칙
  - secret/config 분리 전략
- 입력:
  - node label 체계
  - storage class 또는 host/device 전략
  - 도메인/ingress 정책
- 출력:
  - observability 배치 파일
  - Langfuse 배치 파일
- 완료 기준:
  - Metrics/Logs/Traces/Langfuse 각 계층의 배치 책임이 분리된다.
  - DB, ClickHouse, Langfuse가 목표 노드 역할에 맞게 스케줄된다.

### T7. 검증/보안/문서 기준선

- 목적:
  - 각 lane이 같은 완료 정의를 공유하도록 검증 기준을 묶는다.
- 방향성:
  - Terraform 정적 검증, 보안 스캔, 리뷰 체크리스트를 먼저 고정한다
  - 실행 불가 환경에서는 "실행해야 할 검증"과 "로컬에서 불가한 검증"을 분리 기록한다
- 권장 skill:
  - `terraform-skill`
  - `cloudshell-iac-pipeline`
  - `security-review`
  - `code-review`
- 권장 subagent role:
  - `verifier` 또는 `writer`
- 주요 산출물:
  - 검증 체크리스트
  - 보안 체크리스트
  - PR/review 기준
- 완료 기준:
  - 모든 lane이 공통으로 참조할 단일 검증 기준이 존재한다.
  - IAM 제약, CloudShell 제약, 네트워크 제약이 테스트 해석에 반영된다.

### T8. CI/CD 및 운영 파이프라인

- 목적:
  - CloudShell 기반 실행과 GitHub Actions 기반 자동화 경로를 정리한다.
- 방향성:
  - Terragrunt/Terraform plan/apply 경로를 자동화 기준으로 삼는다
  - 장시간 실행, 세션 만료, 상태 관리 리스크를 반영한다
  - 아직 결정되지 않은 remote backend는 선택지로 남기고 인터페이스만 고정한다
- 권장 skill:
  - `terraform-skill`
- 권장 subagent role:
  - `executor`
- 주요 산출물:
  - 실행 파이프라인 문서
  - GitHub Actions 초안
  - 수동 승인 단계 정의
- 완료 기준:
  - 누가 어디서 `plan/apply`를 돌리는지 명확하다.
  - CloudShell 제약과 장시간 실행 대응이 포함된다.

## 5. Subagent Brief Templates

아래 템플릿을 그대로 subagent 시작 프롬프트로 사용한다.

### Template A: Terraform Lane

```text
문맥:
- 저장소 기준 문서: docs/tasks/subagent-task-orchestration.md, docs/PRD.md, docs/architecture.md
- 이 lane의 task ID: <T1|T2|T3|T4|T8>
- 공통 방향성: 기본 VPC 재사용, 7노드 목표, 초기 SG는 server + worker-shared

할 일:
- 위 문서의 해당 task 섹션만 수행
- 새 결정을 만들지 말고, 모호하면 문서에 미결정으로 남겨 상위로 에스컬레이션
- 변경 파일과 이유를 마지막에 요약

필수:
- terraform-skill 기준 구조/변수/출력/검증 방식을 따른다
- 다른 lane의 작업을 되돌리지 않는다
```

### Template B: Kubernetes Lane

```text
문맥:
- 저장소 기준 문서: docs/tasks/subagent-task-orchestration.md, docs/PRD.md, docs/architecture.md
- 이 lane의 task ID: <T5|T6>
- 7노드 역할 분리 토폴로지와 observability/Langfuse 경계를 유지한다

할 일:
- 해당 task의 산출물만 작성
- Terraform 책임과 Kubernetes 책임을 섞지 않는다
- node label/taint/affinity 전략을 명시적으로 남긴다

필수:
- kubernetes-specialist 기준으로 배치 구조를 정리
- 필요한 입력값과 의존성을 마지막에 요약
```

### Template C: Verification Lane

```text
문맥:
- 저장소 기준 문서: docs/tasks/subagent-task-orchestration.md
- 이 lane의 task ID: T7

할 일:
- 각 lane이 공유할 검증, 보안, 리뷰 기준을 단일 문서/섹션으로 정리
- 실행 가능한 검증과 환경상 불가한 검증을 분리

필수:
- terraform-skill, security-review, code-review 기준을 함께 반영
```

## 6. 추천 실행 순서

subagent를 실제로 띄울 때는 아래 순서를 추천한다.

1. `T1`, `T2`, `T7` 병렬 시작
2. `T1`, `T2` 완료 후 `T3` 시작
3. `T3` 완료 후 `T4`, `T5` 병렬 시작
4. `T5` 완료 후 `T6` 시작
5. `T1`, `T3`, `T5` 인터페이스 고정 후 `T8` 시작

### 첫 위임 wave

- `T1` -> 별도 worktree에서 Terragrunt lane 착수
- `T2` -> 별도 worktree에서 SG bootstrap lane 착수
- `T7` -> 별도 worktree에서 verification/documentation lane 착수

이 3개 lane은 현재 기준으로 가장 충돌이 적고, 이후 `T3` 착수에 필요한 인터페이스를 빠르게 고정할 수 있다.

## 7. 현재 저장소 기준 즉시 착수 후보

현 시점에서 바로 시작 가능한 lane은 다음이다.

- `T1`: 아직 Terragrunt 계층이 없다.
- `T2`: 현재 SG 모듈은 존재하지만 변수 검증/명명/출력 정리가 덜 되어 있다.
- `T7`: 검증 기준 문서는 아직 독립적으로 정리되어 있지 않다.

즉, 첫 병렬 wave는 `T1 + T2 + T7`이 가장 안전하다.
