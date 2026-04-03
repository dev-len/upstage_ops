# K3S Bootstrap Baseline

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: T5 lane의 최소 K3S bootstrap 기준을 고정한다.
- 관련 문서:
  - [subagent-task-orchestration.md](/Users/len/Desktop/project/k8s/docs/tasks/subagent-task-orchestration.md)
  - [validation-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/validation-baseline.md)

## 1. 범위

이 문서는 다음만 다룬다.

- server 1대 bootstrap
- agent N대 join
- role label / taint 전달 규칙
- Terraform 이후 handoff 입력

이 문서는 다음은 다루지 않는다.

- Helm/manifest 배치
- EBS 파일시스템 포맷 및 마운트
- Secret 배포 자동화

## 2. 입력

### Server

- `K3S_TOKEN`
- `K3S_NODE_NAME`
- `K3S_NODE_LABELS`
- `K3S_NODE_TAINTS` (선택)
- `K3S_SERVER_ARGS` (선택)

### Agent

- `K3S_TOKEN`
- `K3S_SERVER_HOST`
- `K3S_NODE_NAME`
- `K3S_NODE_LABELS`
- `K3S_NODE_TAINTS` (선택)
- `K3S_AGENT_ARGS` (선택)

## 3. 스크립트

- server: [server-init.sh](/Users/len/Desktop/project/k8s/bootstrap/k3s/server-init.sh)
- agent: [agent-init.sh](/Users/len/Desktop/project/k8s/bootstrap/k3s/agent-init.sh)

## 4. 기본 role 정책

추천 label:

- server: `topology.k3s.io/role=server`
- app: `topology.k3s.io/role=app`
- metrics: `topology.k3s.io/role=metrics`
- logs-traces: `topology.k3s.io/role=logs-traces`
- db: `topology.k3s.io/role=db`
- llm-obs: `topology.k3s.io/role=llm-obs`
- clickhouse: `topology.k3s.io/role=clickhouse`

추천 taint:

- server: `dedicated=server:NoSchedule` 또는 control-plane taint
- metrics: `dedicated=metrics:NoSchedule`
- logs-traces: `dedicated=logs-traces:NoSchedule`
- db: `dedicated=db:NoSchedule`
- llm-obs: `dedicated=llm-obs:NoSchedule`
- clickhouse: `dedicated=clickhouse:NoSchedule`

App 노드는 초기에는 taint 없이 두고, 이후 workload 분리가 필요하면 추가한다.

## 5. Terraform과의 경계

- Terraform은 인스턴스, SG, EBS, IP 정보를 제공한다.
- bootstrap 스크립트는 그 정보를 입력으로 받아 K3S를 조립한다.
- Kubernetes workload 배치는 이후 lane에서 다룬다.

## 6. 최소 handoff 출력

T5가 이후 lane에 넘겨야 할 최소 정보는 다음이다.

- server private IP
- server public IP
- server endpoint (`https://<server_private_ip>:6443`)
- server instance ID
- worker private/public IP 목록
- role별 node name 정책
- role별 label/taint 정책
