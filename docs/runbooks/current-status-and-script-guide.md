# Current Status and Script Guide

- 문서 상태: Draft
- 작성일: 2026-04-06
- 목적: 현재까지의 진행 상황, 실제로 겪은 실패 원인, CloudShell에서 사용하는 스크립트의 역할과 실행 순서를 한 곳에 정리한다.

## 1. 현재 상태

### 완료된 것

- Terraform/Terragrunt baseline과 AWS output 수집 경로 정리
- bastion instance 생성
- 8개 K3S node instance 생성
- `terragrunt output -json` 기준 bastion / node IP와 role 맵 확인
- server node에서 K3S 설치 확인
- server node에서 `kubectl get nodes` 기준 `server` 단독 `Ready` 확인

### 아직 미완료인 것

- worker node 자동 join 확인
- 전체 node `Ready` 상태 확인
- bastion helper의 AWS credential 없는 운영 경로 정리
- Phase 3 evidence의 실제 CloudShell 결과 저장
- observability / Langfuse / sample app 배포

## 2. 실패 이력과 원인

아래는 실제로 확인된 실패만 정리한다.

### 기존 SG duplicate SSH rule

- 증상:
  - `InvalidPermission.Duplicate`
- 원인:
  - 기존 SG에 이미 `bastion -> server/worker : 22/tcp` 규칙이 있는데 Terraform이 다시 생성 시도
- 조치:
  - `manage_existing_bastion_ssh_ingress_rules = false`

### bastion helper 미설치 / 미반영

- 증상:
  - bastion 접속 후 helper 스크립트가 없음
- 원인:
  - 새 `user_data`가 들어간 인스턴스로 교체되지 않음
- 조치:
  - bastion은 `-replace='aws_instance.bastion[0]'` 필요

### templatefile 파싱 오류

- 증상:
  - `Invalid character`
  - `vars map does not contain key ...`
- 원인:
  - Terraform 템플릿 문법과 Bash `${...}` 보간 충돌
- 조치:
  - heredoc 내부 Bash 변수 escape 정리

### node cycle

- 증상:
  - `Cycle: module.k3s_nodes...`
- 원인:
  - worker `user_data`가 같은 `for_each` 리소스 안에서 server private IP 참조
- 조치:
  - `aws_instance.server`와 worker `aws_instance.node` 분리

### `ModifyInstanceAttribute` 권한 오류

- 증상:
  - `ec2:ModifyInstanceAttribute` 403
- 원인:
  - server가 replace되지 않고 기존 인스턴스의 `user_data` in-place 수정으로 흘러감
- 조치:
  - `scripts/cloudshell-replace-apply.sh`의 replace 주소를 `module.k3s_nodes.aws_instance.server`로 수정

### bastion AWS credential 부재

- 증상:
  - `/opt/k3s-bootstrap/server.sh` 실행 시 `Unable to locate credentials`
- 원인:
  - helper는 내부적으로 `aws ec2 describe-instances`를 사용하지만 bastion에 credential / instance profile이 없음
- 조치:
  - server private IP로 직접 SSH

### SSH 키/포트 문제

- 증상:
  - `Permission denied (publickey)`
  - bastion 접속 실패
- 원인:
  - bastion 외부 포트는 `22022`
  - PEM 권한이 `0644`
  - bastion에 key가 없음
- 조치:
  - `chmod 600`
  - `-p 22022`
  - 필요 시 bastion에 PEM 복사

### server만 Ready, worker 미join

- 현재 사실:
  - server node는 `Ready`
  - worker는 아직 cluster에 나타나지 않음
- 아직 미확인:
  - worker별 `k3s-agent` 상태
  - worker cloud-init/user_data 실패 여부

### worker node 이름 RFC 1123 위반

- 증상:
  - `Node "app_1" is invalid`
  - `Node "app_2" is invalid`
  - `Node "logs_traces" is invalid`
  - `Node "llm_obs" is invalid`
- 원인:
  - Kubernetes node name은 `_`를 허용하지 않는데, 자동 bootstrap이 Terraform logical name을 그대로 `--node-name`에 넘김
- 조치:
  - Terraform logical name과 별도로 K3S runtime node name을 `_ -> -`로 정규화
  - 예: `app_1 -> app-1`, `logs_traces -> logs-traces`, `llm_obs -> llm-obs`

## 3. 스크립트 가이드

### `scripts/cloudshell-plan.sh`

- 목적:
  - CloudShell에서 plan 실행과 output 저장
- 실행 위치:
  - CloudShell, repo root
- 결과:
  - `artifacts/evidence/terragrunt-plan.txt`
  - `artifacts/evidence/terragrunt-output.json`

### `scripts/cloudshell-replace-apply.sh`

- 목적:
  - bastion + 전체 node를 replace apply
- 실행 위치:
  - CloudShell, repo root
- 주의:
  - `inputs.hcl` 값이 먼저 채워져 있어야 함
  - 기존 인스턴스의 first-boot 자동화를 실제 반영하는 핵심 스크립트

### `scripts/phase3-verify.sh`

- 목적:
  - bastion helper 존재와 server kubeconfig / node 상태 확인
- 실행 위치:
  - server에서 실행하는 것을 기본으로 봄
- 결과:
  - `phase3-bastion-helper-check.txt`
  - `phase3-server-kubeconfig-check.txt`
  - `phase3-kubectl-get-nodes.txt`
  - `phase3-kubectl-get-nodes-labels.txt`

### `scripts/sync-bastion-wrappers.sh`

- 목적:
  - CloudShell에서 최신 Terraform output을 읽고 bastion `~/bin`에 node별 SSH wrapper를 재생성/업로드
- 실행 위치:
  - CloudShell, repo root
- 전제:
  - bastion SSH 접속 가능
  - `terragrunt output -json` 또는 `artifacts/evidence/terragrunt-output.json` 존재
- 결과:
  - bastion `~/bin/server.sh`
  - bastion `~/bin/app_1.sh`
  - bastion `~/bin/app-1.sh`
  - 기타 node별 wrapper
- 주의:
  - bastion 자체에 AWS credential이 없어도 동작한다
  - IP 변경 시 이 스크립트를 다시 실행해 wrapper를 갱신한다

### `scripts/capture-phase-evidence.sh`

- 목적:
  - 현재 환경 기준 `blocked` / 기본 evidence 파일 생성
- 실행 위치:
  - 로컬 또는 CloudShell
- 주의:
  - 실제 kubeconfig나 terragrunt가 없으면 `blocked`를 남기는 용도

### `scripts/bootstrap-k3s-role.sh`

- 역할:
  - fallback 수동 bootstrap
- 사용 시점:
  - 기존 인스턴스를 재사용하거나 자동 bootstrap 실패 원인 분리 확인이 필요할 때만 사용

## 4. 현재 권장 실행 순서

CloudShell 기준 권장 순서는 아래다.

1. `git pull`
2. `terragrunt/dev/inputs.hcl` 확인
3. `bash scripts/cloudshell-plan.sh`
4. `bash scripts/cloudshell-replace-apply.sh`
5. `bash scripts/sync-bastion-wrappers.sh`
6. bastion 접속 후 `~/bin/server.sh` 또는 `~/bin/app-1.sh` 사용
7. server에서 `sudo k3s kubectl get nodes -o wide`
8. server에서 `sudo k3s kubectl get nodes --show-labels`
9. 필요 시 `bash scripts/phase3-verify.sh`

## 5. 다음 진단 포인트

worker가 아직 안 붙는 상태에서 다음으로 볼 항목은 아래다.

- worker node `k3s-agent` 서비스 상태
  - `sudo systemctl status k3s-agent --no-pager`
- worker cloud-init 로그
  - `sudo tail -n 200 /var/log/cloud-init-output.log`
- worker agent journal
  - `sudo journalctl -u k3s-agent -n 200 --no-pager`
- worker -> server API 연결
  - `curl -k https://172.31.74.110:6443/ping`
  - `nc -vz 172.31.74.110 6443`

현재는 worker join 원인을 “실패”로 단정하지 않고, **다음 미해결 이슈**로 본다.

## 관련 문서

- [k3s-auto-bootstrap.md](/Users/len/Desktop/project/k8s/docs/runbooks/k3s-auto-bootstrap.md)
- [cluster-bring-up.md](/Users/len/Desktop/project/k8s/docs/runbooks/cluster-bring-up.md)
- [phase-evidence.md](/Users/len/Desktop/project/k8s/docs/runbooks/phase-evidence.md)
