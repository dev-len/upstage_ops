# Validation Baseline

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: T1-T8 전체 lane이 공통으로 참조할 검증, 보안, 리뷰 기준을 고정한다.
- 범위:
  - Terraform / Terragrunt / AWS IaC
  - Kubernetes manifests / Helm values / bootstrap scripts
  - 보안 점검
  - PR / review 기준

## 1. 공통 원칙

- 검증은 "실행 가능"과 "현재 환경에서 차단됨"을 분리해서 기록한다.
- 로컬에 `terraform` 또는 `terragrunt` 바이너리가 없으면, 그 검증은 실패가 아니라 `blocked`로 기록한다.
- CloudShell 제약, IAM 제약, 네트워크 제약은 검증 해석에 포함한다.
- raw `tfstate`를 Git에 커밋하지 않는다.
- 각 lane은 변경 목적, 영향 범위, 검증 결과를 같이 남긴다.

## 2. 실행 환경 구분

### 2.1 로컬 개발 환경

- 확인할 것:
  - 파일 구조
  - 문서 일치성
  - 정적 검토 가능 여부
- 주의할 것:
  - Terraform / Terragrunt / Trivy / Checkov / TFLint 설치 여부는 환경마다 다를 수 있다

### 2.2 CloudShell

- 확인할 것:
  - `HOME` 영속 저장소 크기
  - 세션 만료 리스크
  - 장시간 실행 시 `tmux` 또는 분할 실행 필요성
- 주의할 것:
  - provider cache 및 state 저장 위치
  - `/tmp/.terragrunt-cache`, `/tmp/.terraform-plugin-cache` 사용 여부
  - `TG_DOWNLOAD_DIR` 사용 여부
  - remote backend 사용 가능 여부
  - 인증/권한 부족 시 plan/apply 차단 가능성
  - 학습 계정 정책 때문에 `ec2:RevokeSecurityGroupEgress`가 차단될 수 있음

### 2.3 AWS 학습용 계정

- 확인할 것:
  - VPC / subnet / route table / IGW 수정 가능 여부
  - SG 생성/수정 가능 여부
  - EC2 수량/인스턴스 타입 제한
  - S3 / DynamoDB 사용 가능 여부

## 3. Terraform / Terragrunt 검증

### 필수

- `terraform fmt -check`
- `terraform validate`
- `terragrunt hclfmt`
- `terragrunt validate`

### 조건부

- `terraform test`
  - Terraform 1.6+이고 테스트 파일이 있을 때 수행
- `terragrunt plan`
  - backend / provider / credentials가 준비됐을 때 수행

### 보조

- `tflint`
- `checkov -d .`
- `trivy config .`

### 합격 기준

- 포맷 오류가 없다.
- 변수와 출력이 선언과 일치한다.
- plan 결과가 의도한 변경만 포함한다.
- 외부 의존성 때문에 막히면, 막힌 이유를 명시한다.

## 4. Kubernetes / Helm 검증

### 필수

- `helm lint` 또는 차트가 없으면 해당 없음
- `kubectl apply --dry-run=client`
- YAML 문법 점검

### 조건부

- 실제 클러스터 연결이 가능하면 `kubectl diff` 또는 `helm template` 결과 확인
- 배포 대상 노드/스토리지/ingress가 정해졌으면 scheduling 규칙 검토

### 합격 기준

- 매니페스트가 문법적으로 유효하다.
- nodeSelector / affinity / toleration 의도가 문서와 일치한다.
- stateful workload는 저장소 전제와 함께 기록된다.

## 5. 보안 체크리스트

### IaC 공통

- [ ] 비밀값을 변수 기본값이나 문서에 평문으로 두지 않는다.
- [ ] `0.0.0.0/0` 허용 범위는 의도적으로만 사용한다.
- [ ] SSH는 관리자 CIDR로만 제한한다.
- [ ] 내부 통신은 가능하면 SG 참조를 사용한다.
- [ ] 데이터 계층 포트는 외부 공개하지 않는다.
- [ ] raw `tfstate`는 저장소에 넣지 않는다.

### AWS / 네트워크

- [ ] 기존 VPC와 기존 서브넷만 사용한다.
- [ ] 네트워크 리소스 수정 권한이 없으면, 생성/변경을 시도하지 않는다.
- [ ] IGW / route / subnet 수정은 권한 확인 후에만 다룬다.
- [ ] SG bootstrap 단계에서는 outbound를 Terraform이 직접 관리하지 않는 기본 구성을 우선 사용한다.
- [ ] 기본 allow-all egress를 대체하려면 `ec2:RevokeSecurityGroupEgress` 권한 여부를 먼저 확인한다.

### Kubernetes

- [ ] Secret은 Kubernetes Secret 또는 외부 비밀 관리로 다룬다.
- [ ] 기본 인증과 접근 제어는 문서화한다.
- [ ] workload는 역할별 노드에 배치한다.

## 6. PR / Review 기준

### PR에 반드시 포함할 것

- 변경 이유
- 변경 파일 목록
- 어떤 lane에 속하는지
- 수행한 검증
- 차단된 검증과 이유
- 남은 위험

### 리뷰에서 확인할 것

- 작업 범위가 lane과 일치하는가
- 다른 lane의 책임을 침범하지 않는가
- 문서와 코드가 같은 사실을 말하는가
- 검증이 실제로 의미 있는가
- 보안 원칙을 어기지 않는가

### 승인 기준

- 공통 기준 문서와 task 문서가 서로 모순되지 않는다.
- T1-T8에 대한 최소 검증 경로가 존재한다.
- 실패한 검증은 실패/차단 이유까지 남겼다.

## 7. Lane별 최소 검증 표준

| Lane | 필수 검증 | 조건부 검증 | 비고 |
|------|-----------|-------------|------|
| T1 | `terraform fmt -check`, `terragrunt hclfmt` | `terragrunt validate`, `terragrunt plan` | Terragrunt 계층이 핵심 |
| T2 | `terraform fmt -check`, `terraform validate` | `checkov -d .`, `trivy config .` | SG 규칙과 변수 검증 포함 |
| T3 | `terraform fmt -check`, `terraform validate` | `terraform plan` | EC2 리소스/출력 일치성 확인 |
| T4 | `terraform fmt -check`, `terraform validate` | `terraform plan` | EBS attachment와 AZ 의존성 확인 |
| T5 | shell syntax check | 런타임 bootstrap 검증 | `bootstrap/k3s/*.sh`, env 계약, label/taint 절차 검토 |
| T6 | YAML / Helm lint, `kubectl kustomize` | `helm template`, `kubectl diff` | `deployments/observability/*`, `deployments/langfuse/*`, `kubernetes/*` 검토 |
| T7 | 문서 일치성 점검 | 리뷰 체크리스트 적용 | 이 문서가 산출물 |
| T8 | `terraform fmt -check`, `terraform validate` | `terragrunt plan`, pipeline dry-run | CloudShell / GitHub Actions 경계 확인 |

## 8. 최소 완료 정의

각 lane이 완료라고 말하려면 다음이 있어야 한다.

- 무엇을 바꿨는지
- 무엇을 확인했는지
- 무엇이 차단됐는지
- 차단이 환경 때문인지, 권한 때문인지, 설계 미결정 때문인지

이 네 가지가 없으면 완료로 인정하지 않는다.
