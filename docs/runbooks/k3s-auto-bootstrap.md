# K3S Auto Bootstrap Runbook

- 문서 상태: Draft
- 작성일: 2026-04-06
- 목적: K3S first-boot 자동 bootstrap의 입력, 동작 방식, 재적용 전략, 검증 기준을 한 곳에 고정한다.

현재까지의 실제 진행 상황과 실패 이력은 [current-status-and-script-guide.md](/Users/len/Desktop/project/k8s/docs/runbooks/current-status-and-script-guide.md)를 본다.

## 1. 목적과 전제

이 문서는 Terraform `apply` 이후 새로 생성되는 bastion과 K3S node가 사람 SSH 개입 없이 자동 초기화되는 경로를 설명한다.

자동화 대상:

- bastion helper 자동 설치
- server node K3S server 자동 설치
- worker node K3S agent 자동 join
- role별 label / taint 자동 적용

자동화 비대상:

- 이미 실행 중인 기존 인스턴스
- Helm chart 설치 자체의 세부 구현
- observability / Langfuse workload 배포의 Secret 입력 준비
- evidence 후속 해석 자동화

## 2. 입력 변수와 기본값

자동 bootstrap 관련 핵심 입력은 아래다.

- `bootstrap_bastion_helpers = true`
  - bastion 첫 부팅에서 `/opt/k3s-bootstrap` helper 설치
- `k3s_bootstrap_token = "<shared-token>"`
  - server / worker first-boot K3S 설치 활성화
- `k3s_server_extra_args = ""`
  - server install 추가 인자
- `k3s_agent_extra_args_by_role = {}`
  - 역할별 agent install 추가 인자
- `manage_existing_bastion_ssh_ingress_rules = true`
  - 기존 SG를 주입해도 Terraform이 현재 ingress를 검사하고 누락된 bastion/admin SSH 규칙만 추가한다
  - 기존 SG 주입 경로에서 duplicate SSH rule 회피

권장 기본값:

```hcl
bootstrap_bastion_helpers                 = true
manage_existing_bastion_ssh_ingress_rules = true
k3s_bootstrap_token                       = "replace-me-with-a-shared-token"
```

## 3. 새 인스턴스 기준 동작 흐름

### Bastion

- Terraform이 bastion instance를 생성한다.
- bastion `user_data`가 `/opt/k3s-bootstrap` 아래 helper를 설치한다.
- bastion `user_data`가 `/opt/k3s-bootstrap/id_bastion_nodes`에 private node 접속용 기본 SSH key를 설치한다.
- helper는 EC2 `Name` 태그 기준으로 private node의 최신 private IP를 조회한다.
- helper는 기본적으로 `/opt/k3s-bootstrap/id_bastion_nodes`를 사용해 private node에 접속한다.
- bastion SSH 데몬은 first-boot에 `bastion_ssh_port`로 맞춰진다.

### Server

- server node first boot에서 K3S server 설치가 실행된다.
- server node first boot에서 bastion helper 공개키를 `ubuntu`의 `authorized_keys`에 추가한다.
- `topology.k3s.io/role=server` label이 적용된다.
- `k3s_server_extra_args`가 있으면 install 명령 뒤에 추가된다.

### Worker

- worker node first boot에서 K3S agent 설치가 실행된다.
- worker node first boot에서 bastion helper 공개키를 `ubuntu`의 `authorized_keys`에 추가한다.
- agent는 server private IP 기준으로 API 응답을 기다린 뒤 join을 시도한다.
- role별 label과 infra 전용 taint가 자동 적용된다.
- Kubernetes runtime node name은 RFC 1123 규칙을 따르기 위해 logical name의 `_`를 `-`로 정규화해서 사용한다.

기본 role 매핑:

- `app` -> `topology.k3s.io/role=app`
- `metrics` -> `topology.k3s.io/role=metrics`, `dedicated=metrics:NoSchedule`
- `logs_traces` -> `topology.k3s.io/role=logs-traces`, `dedicated=logs-traces:NoSchedule`
- `db` -> `topology.k3s.io/role=db`, `dedicated=db:NoSchedule`
- `llm_obs` -> `topology.k3s.io/role=llm-obs`, `dedicated=llm-obs:NoSchedule`
- `clickhouse` -> `topology.k3s.io/role=clickhouse`, `dedicated=clickhouse:NoSchedule`

## 4. 기존 인스턴스에 바로 안 붙는 이유

EC2 `user_data`는 기본적으로 첫 부팅 시점에 실행된다.
따라서 이미 생성되어 실행 중인 bastion / node는 `bootstrap_bastion_helpers`나 `k3s_bootstrap_token`을 나중에 넣어도 자동으로 새 bootstrap을 받지 않는다.

즉:

- 입력값 추가만으로는 충분하지 않다
- 인스턴스 재생성 또는 `-replace`가 필요하다

## 5. 재적용 전략

### Bastion만 교체

bastion helper 자동 설치만 반영하려면:

```bash
cd terragrunt/dev
terragrunt apply -replace='aws_instance.bastion[0]'
```

### 전체 node 교체

K3S first-boot bootstrap까지 새 경로를 반영하려면:

```bash
bash scripts/cloudshell-replace-apply.sh
```

기존 SG 주입 경로에서는 아래를 유지한다.

```hcl
manage_existing_bastion_ssh_ingress_rules = true
```

## 6. Apply 후 검증

### Bastion helper 확인

```bash
ssh -p 22022 ubuntu@${BASTION_PUBLIC_IP}
ls -la /opt/k3s-bootstrap
ls -l /opt/k3s-bootstrap/id_bastion_nodes
/opt/k3s-bootstrap/server.sh hostname
```

### Node Ready 확인

server kubeconfig를 사용해 아래를 확인한다.

```bash
bash scripts/phase3-verify.sh
```

CloudShell 표준 경로에서는 아래 스크립트가 최대 20분 동안 전체 node `Ready`를 기다린다.

```bash
SSH_IDENTITY_FILE=~/.ssh/k3s-dev-key.pem bash scripts/cloudshell-k3s-check.sh
```

### 기대 결과

- bastion에 `/opt/k3s-bootstrap` 존재
- bastion에 `/opt/k3s-bootstrap/id_bastion_nodes` 존재
- bastion에서 `/opt/k3s-bootstrap/server.sh hostname`이 동작
- 전체 node가 `Ready`
- role label이 역할별로 일치
- infra node taint가 적용
- timeout 시 worker diagnostics가 저장되고 workload 단계는 중단됨

## 7. 흔한 실패 패턴

- `user_data` 미반영
  - 기존 인스턴스를 재사용 중인데 `-replace`를 하지 않음
- duplicate SG rule
  - 기존 SG에 이미 bastion -> server/worker `22/tcp` 규칙이 있는데 Terraform이 다시 만들려 함
- agent join 실패
  - server API 미응답
  - `k3s_bootstrap_token` 불일치
- IP 변동
  - EIP 미사용으로 bastion public IP와 node private IP가 바뀔 수 있음
  - output 또는 AWS tag 조회로 최신 IP를 다시 확인해야 함
- bastion helper 실패
  - AWS CLI 권한 부족
  - EC2 `Name` 태그 규칙 불일치

## 8. 로그와 evidence

Phase 3에서 최소로 남길 증거는 아래다.

- bastion helper 설치 확인 결과
- `kubectl get nodes -o wide`
- `kubectl get nodes --show-labels`
- server / worker bootstrap 로그 위치
- kubeconfig 확보 여부

기본 저장 위치:

- `artifacts/evidence/phase3-bastion-helper-check.txt`
- `artifacts/evidence/phase3-kubectl-get-nodes.txt`
- `artifacts/evidence/phase3-kubectl-get-nodes-labels.txt`
- `artifacts/evidence/summary.md`

관련 문서:

- [cluster-bring-up.md](/Users/len/Desktop/project/k8s/docs/runbooks/cluster-bring-up.md)
- [phase-evidence.md](/Users/len/Desktop/project/k8s/docs/runbooks/phase-evidence.md)
