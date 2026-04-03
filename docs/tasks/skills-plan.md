# Skills Plan

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: 현재 task 기준으로 필요한 skill을 분류하고, 이미 있는 skill과 추가 검토 skill을 정리한다.
- 기준 문서:
  - [subagent-task-orchestration.md](/Users/len/Desktop/project/k8s/docs/tasks/subagent-task-orchestration.md)

## 1. 현재 task 기준 skill 커버리지

현재 task 매트릭스 기준으로는 아래처럼 정리된다.

### 이미 있는 skill로 충분한 영역

- `terraform-skill`
  - `T1`, `T2`, `T3`, `T4`, `T8`
  - Terraform 모듈 구조, 변수/출력 설계, 테스트/검증, CI/CD 뼈대까지 기본 커버 가능
- `kubernetes-specialist`
  - `T5`, `T6`
  - K3S bootstrap 이후 쿠버네티스 배치, 스케줄링, 보안 경계 정리에 적합
- `security-review`
  - `T7`
  - Terraform/Kubernetes 산출물의 보안 검토 기준 작성에 적합
- `code-review`
  - `T7`
  - 각 lane 산출물의 리뷰 기준선 정리에 적합
- `parallel-infra-orchestrator`
  - 전체 task 분해, `docs/tasks` 기준 정렬, lane별 위임 준비
  - 외부 generic skill보다 현재 저장소 제약을 반영한 로컬 orchestration 용도에 적합
- `terragrunt-bootstrap`
  - `T1`
  - Terragrunt 계층 설계를 이 저장소의 CloudShell/AWS 제약에 맞춰 고정하는 용도
- `k3s-observability-lane`
  - `T6`
  - OTel, Loki, Tempo, Grafana, Langfuse 배치 책임을 7노드 기준으로 정리하는 용도
- `cloudshell-iac-pipeline`
  - `T8`
  - CloudShell과 GitHub Actions 경계를 반영한 IaC 파이프라인 정리용

### 추가 검토는 가능하지만 로컬 skill로 우선 해결한 영역

- Terragrunt 계층 설계
  - `terragrunt-bootstrap`으로 우선 해결한다.
- OTel/observability 세부 설계
  - `k3s-observability-lane`으로 우선 해결한다.
- GitHub Actions / CI workflow 작성
  - `cloudshell-iac-pipeline`으로 우선 해결한다.

### 외부 skill 대신 로컬 skill로 해결하기로 한 영역

- subagent 병렬 오케스트레이션
  - 외부 skill 검색보다 현재 저장소 기준 문서와 제약을 직접 반영하는 로컬 skill이 더 적합하다.
  - 따라서 `.agents/skills/parallel-infra-orchestrator`를 기준 skill로 사용한다.

## 2. $find-skills 검색 결과

아래는 `npx skills find ...`로 조회한 결과다.

### Terragrunt 관련

- `akin-ozer/cc-devops-skills@terragrunt-generator`
  - 설치: `npx skills add akin-ozer/cc-devops-skills@terragrunt-generator`
  - 링크: https://skills.sh/akin-ozer/cc-devops-skills/terragrunt-generator
- `akin-ozer/cc-devops-skills@terragrunt-validator`
  - 설치: `npx skills add akin-ozer/cc-devops-skills@terragrunt-validator`
  - 링크: https://skills.sh/akin-ozer/cc-devops-skills/terragrunt-validator

### Kubernetes / Observability 관련

- `julianobarbosa/claude-code-skills@opentelemetry`
  - 설치: `npx skills add julianobarbosa/claude-code-skills@opentelemetry`
  - 링크: https://skills.sh/julianobarbosa/claude-code-skills/opentelemetry
- `nmime/infra-skills@k8s-observability`
  - 설치: `npx skills add nmime/infra-skills@k8s-observability`
  - 링크: https://skills.sh/nmime/infra-skills/k8s-observability
- `olino3/forge@kubernetes-specialist`
  - 설치: `npx skills add olino3/forge@kubernetes-specialist`
  - 링크: https://skills.sh/olino3/forge/kubernetes-specialist

### CI/CD / GitHub Actions 관련

- `vamseeachanta/workspace-hub@github-actions`
  - 설치: `npx skills add vamseeachanta/workspace-hub@github-actions`
  - 링크: https://skills.sh/vamseeachanta/workspace-hub/github-actions
- `aidotnet/moyucode@ci-cd-generator`
  - 설치: `npx skills add aidotnet/moyucode@ci-cd-generator`
  - 링크: https://skills.sh/aidotnet/moyucode/ci-cd-generator

## 3. Task별 권장 skill 조합

| Task | 기본 skill | 추가 검토 skill | 판단 |
|------|------------|----------------|------|
| `T1` | `terraform-skill`, `terragrunt-bootstrap` | `terragrunt-generator`, `terragrunt-validator` | 로컬 skill 우선 |
| `T2` | `terraform-skill` | 없음 | 현재 skill로 충분 |
| `T3` | `terraform-skill` | 없음 | 현재 skill로 충분 |
| `T4` | `terraform-skill` | 없음 | 현재 skill로 충분 |
| `T5` | `kubernetes-specialist` | 없음 | 현재 skill로 충분 |
| `T6` | `kubernetes-specialist`, `k3s-observability-lane` | `opentelemetry`, `k8s-observability` | 로컬 skill 우선 |
| `T7` | `terraform-skill`, `security-review`, `code-review` | 없음 | 현재 skill로 충분 |
| `T8` | `terraform-skill`, `cloudshell-iac-pipeline` | `github-actions`, `ci-cd-generator` | 로컬 skill 우선 |

## 4. 권장 결론

현재 저장소 기준 결론은 다음과 같다.

### 유지

- `terraform-skill`
- `kubernetes-specialist`
- `security-review`
- `code-review`
- `parallel-infra-orchestrator` (로컬 신규)
- `terragrunt-bootstrap` (로컬 신규)
- `k3s-observability-lane` (로컬 신규)
- `cloudshell-iac-pipeline` (로컬 신규)

### 외부 후보 중 참고만 유지할 것

1. `akin-ozer/cc-devops-skills@terragrunt-generator`
2. `akin-ozer/cc-devops-skills@terragrunt-validator`
3. `julianobarbosa/claude-code-skills@opentelemetry`

즉, 즉시 병렬 작업에는 현재 설치 skill + 로컬 skill 묶음이 우선이다.

## 5. 운영 원칙

- skill 추가 전에도 `T1 + T2 + T7`은 바로 시작 가능하다.
- `parallel-infra-orchestrator`는 task 문서 정리와 subagent dispatch 준비의 기본 skill로 사용한다.
- `terragrunt-bootstrap`, `k3s-observability-lane`, `cloudshell-iac-pipeline`은 외부 generic skill 대체용 로컬 skill이다.
- skill 설치는 task 착수 전 필수 조건이 아니라, lane 품질 향상을 위한 선택 사항이다.
- 새 skill을 설치하면 해당 task 문서와 subagent brief template에도 반영한다.
