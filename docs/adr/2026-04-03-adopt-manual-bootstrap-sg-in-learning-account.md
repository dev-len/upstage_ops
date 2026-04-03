# [ADR-2026-04-03] 학습 계정에서 수동 bootstrap SG 주입 경로 채택

- **상태**: Accepted
- **날짜**: 2026-04-03

## 맥락 (Context)

AWS 학습 계정에서 K3S bootstrap용 Security Group을 Terraform `aws_security_group` 리소스로 생성하려고 했지만, apply 단계에서 반복적으로 실패했다.

확인된 사실은 다음과 같다.

- Security Group 생성 자체는 성공한다
- 생성 직후 Terraform/AWS provider가 기본 outbound rule을 정리하려고 시도한다
- 이 과정에서 `ec2:RevokeSecurityGroupEgress`가 필요하다
- 현재 IAM 정책 `ControlOnlyOwnResources`가 이 작업을 명시적으로 거부한다
- 웹 콘솔에서 outbound rule 삭제를 직접 시도해도 같은 권한 오류가 발생한다

즉 문제는 SG 생성 권한 자체가 아니라, 생성 후 기본 outbound rule을 삭제하거나 재조정하는 권한이 없다는 점이다.

## 결정 (Decision)

학습 계정 기준 bootstrap 단계에서는 Security Group을 Terraform이 직접 생성하려 하지 않는다.

대신 다음 경로를 기본 운영 방식으로 채택한다.

1. AWS CLI 또는 웹 콘솔로 server SG와 worker-shared SG를 먼저 만든다
2. 기본 outbound allow-all rule은 그대로 둔다
3. 필요한 inbound rule만 추가한다
4. Terraform/Terragrunt에는 기존 SG ID를 입력으로 주입한다

dev 환경은 이를 위해 아래 입력을 지원한다.

- `existing_server_security_group_id`
- `existing_worker_shared_security_group_id`

두 값이 함께 주어지면 Terraform은 bootstrap SG 생성 모듈을 건너뛰고, EC2와 스토리지 baseline만 계속 진행한다.

## 검토한 대안 (Alternatives Considered)

### 대안 1: `aws_security_group` 리소스를 그대로 유지

- **장점**: Terraform만으로 SG를 선언적으로 관리할 수 있다
- **단점**: 생성 직후 기본 outbound rule revoke 단계에서 계속 실패한다
- **탈락 사유**: 현재 학습 계정 IAM 정책과 충돌한다

### 대안 2: inline `egress` 또는 egress 리소스로 outbound를 명시 관리

- **장점**: 의도한 outbound 정책을 코드로 표현할 수 있다
- **단점**: outbound를 Terraform이 관리하는 순간 `RevokeSecurityGroupEgress` 경로를 피하지 못한다
- **탈락 사유**: 동일한 권한 오류가 반복된다

### 대안 3: `ignore_changes = [egress]`로 drift만 무시

- **장점**: provider가 만든 기본 outbound rule을 Terraform이 덜 엄격하게 보도록 유도할 수 있다
- **단점**: create 시점 동작을 완전히 우회하지 못할 수 있다
- **탈락 사유**: 학습 계정에서 bootstrap SG 경로를 안정적으로 보장하지 못한다

## 결과 (Consequences)

### 긍정적

- 학습 계정 IAM 제약 안에서도 bootstrap EC2 baseline을 계속 진행할 수 있다
- SG 관련 실패를 Terraform provider 동작에 의존하지 않고 우회할 수 있다
- CloudShell 실행 절차가 실제 계정 제약과 일치하게 된다

### 부정적

- bootstrap 단계에 수동 작업이 추가된다
- SG가 Terraform 완전 관리 대상이 아니므로 일관성 유지 책임이 일부 운영자에게 남는다

### 리스크

- 수동으로 만든 SG 규칙이 문서 기준과 어긋날 수 있다
- SG ID 입력을 잘못 넣으면 잘못된 노드에 잘못된 규칙이 연결될 수 있다

### 완화책

- 루트 README와 Terragrunt README에 CloudShell 기준 SG 생성/ingress 설정 절차를 고정한다
- `existing_server_security_group_id`와 `existing_worker_shared_security_group_id`는 둘 다 주거나 둘 다 비우도록 검증한다
- bootstrap SG가 안정화된 뒤 역할별 SG 세분화는 별도 결정으로 다시 다룬다

## 참고 (References)

- [루트 실행 가이드](../README.md)
- [Terragrunt 실행 가이드](../terragrunt/README.md)
- [K3S 7노드 역할 분리 토폴로지](./006-adopt-k3s-seven-node-topology.md)
