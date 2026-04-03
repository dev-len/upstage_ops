# IaC Pipeline Baseline

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: CloudShell과 GitHub Actions 기준으로 현재 저장소의 IaC 실행 경로를 고정한다.
- 관련 문서:
  - [subagent-task-orchestration.md](/Users/len/Desktop/project/k8s/docs/tasks/subagent-task-orchestration.md)
  - [validation-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/validation-baseline.md)
  - [README.md](/Users/len/Desktop/project/k8s/terragrunt/README.md)

## 1. 기본 원칙

- Terragrunt는 환경 entrypoint다.
- GitHub Actions는 기본적으로 `fmt`, `validate`, `plan`까지 자동화한다.
- `apply`는 자동 실행하지 않는다.
- CloudShell은 사람 승인 후 실제 `plan/apply`를 수행하는 기본 실행면으로 둔다.
- remote backend 가능 여부와 AWS 권한은 전제 조건으로만 문서화하고, 가정하지 않는다.

## 2. 실행 경계

### GitHub Actions

- 수행 대상:
  - `terraform fmt -check`
  - `terragrunt hclfmt --check`
  - `terraform validate`
  - `terragrunt validate`
  - 가능하면 `terragrunt plan`
- 목적:
  - 문법/구조 오류 조기 발견
  - PR에서 변경 영향 요약 제공
- 주의:
  - AWS credentials, backend, provider 설치가 준비되지 않으면 `plan`은 `blocked` 또는 skip 처리
  - `terragrunt/dev/inputs.hcl`은 예시 파일을 복사해 생성하되, placeholder 값 그대로면 실제 plan 성공을 기대하지 않는다

### CloudShell

- 수행 대상:
  - 최종 `terragrunt plan`
  - 수동 승인 후 `terragrunt apply`
- 목적:
  - 실제 AWS 학습용 계정 제약과 CloudShell 제약을 반영한 실행
- 주의:
  - 장시간 실행은 `tmux` 사용
  - `$HOME` 저장소와 provider cache 관리 필요
  - provider download/cache는 `/tmp/.terragrunt-cache`, `/tmp/.terraform-plugin-cache` 사용을 우선한다
  - `TG_DOWNLOAD_DIR`를 사용하고 deprecated `TERRAGRUNT_DOWNLOAD`는 새 설정에 쓰지 않는다
  - 세션 만료와 권한 부족을 감안해 모듈 단위 재실행 가능 구조 유지

권장 예시:

```bash
mkdir -p /tmp/.terragrunt-cache
mkdir -p /tmp/.terraform-plugin-cache

export TG_DOWNLOAD_DIR="/tmp/.terragrunt-cache"
export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugin-cache"
```

## 3. 권장 운영 흐름

1. 개발자는 `terragrunt/dev` 기준으로 변경을 준비한다.
2. PR에서 GitHub Actions가 `fmt`와 `validate`를 실행한다.
3. AWS credentials와 backend가 준비된 경우에만 `plan`을 시도한다.
   - placeholder 입력으로는 validate 중심으로 보고, plan 실패는 `blocked`로 기록한다.
4. PR에는 수행한 검증과 `blocked` 검증을 같이 남긴다.
5. 승인 후 운영자는 CloudShell에서 `terragrunt plan`을 재검증한다.
6. 사람이 확인한 뒤 `terragrunt apply`를 수행한다.

## 4. 차단 가능성

아래는 실패가 아니라 `blocked`로 기록할 수 있다.

- GitHub Actions에 AWS credentials가 없음
- remote backend가 아직 정해지지 않음
- 학습용 계정 IAM 제한으로 `plan` 자체가 막힘
- CloudShell에 필요한 바이너리나 cache 구성이 준비되지 않음

## 5. 최소 PR 보고 형식

- lane ID
- 변경 파일
- 자동 검증 결과
- `blocked` 검증과 이유
- CloudShell 수동 검증 필요 여부
- 남은 위험
