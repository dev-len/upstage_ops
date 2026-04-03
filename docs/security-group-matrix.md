# Security Group 포트 매트릭스

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: 7노드 K3S 기준선에서 필요한 AWS Security Group 포트 범위를 정리하고, Terraform 부트스트랩 단계와 목표 상태의 차이를 명확히 기록한다.
- 관련 문서:
  - [PRD](./PRD.md)
  - [아키텍처](./architecture.md)
  - [네트워크 인벤토리](./network-inventory.md)
  - [ADR-006](./adr/006-adopt-k3s-seven-node-topology.md)

## 1. 범위

이 문서는 AWS Security Group 관점에서 다음을 정리한다.

- 현재 최소 구현 범위
- 7노드 기준 목표 포트 매트릭스
- 외부 노출 포트와 내부 전용 포트 구분
- 아직 결정되지 않은 항목

이 문서는 **포트 설계 문서**이며, 아직 Terraform 코드 구현 상태를 의미하지는 않는다.

## 2. 현재 구현 상태

현재 Terraform 모듈은 [terraform/modules/security-groups/main.tf](/Users/len/Desktop/project/k8s/terraform/modules/security-groups/main.tf) 기준으로 아래만 구현한다.

| 구분 | 상태 |
|------|------|
| 서버 SG 1개 | 구현됨 |
| 공통 워커 SG 1개 | 구현됨 |
| SSH `22/tcp` | 구현됨 |
| K3S API `6443/tcp` | 구현됨 |
| Flannel VXLAN `8472/udp` | 구현됨 |
| Kubelet `10250/tcp` | 구현됨 |
| Ingress `80/443` | 미구현 |
| 역할별 워커 SG 분리 | 미구현 |
| DB 계층 최소 노출 규칙 | 미구현 |

## 3. 기준선 토폴로지

현재 기준선은 7노드 역할 분리다.

| 역할 | 수량 | 비고 |
|------|------|------|
| Server | 1대 | K3S Control Plane |
| App | 2대 | 애플리케이션 워크로드 |
| Metrics | 1대 | Prometheus, Grafana |
| Logs-Traces | 1대 | Loki, Tempo, OTel Collector |
| DB | 1대 | PostgreSQL, Redis |
| LLM-Obs | 1대 | Langfuse Web + Worker |
| ClickHouse | 1대 | ClickHouse 전용 |

## 4. 최소 필수 포트

| 용도 | 포트 | 방향 | 외부 공개 여부 | 설명 |
|------|------|------|---------------|------|
| SSH | `22/tcp` | 관리자 → 노드 | 제한적 | 운영자 접근 |
| K3S API Server | `6443/tcp` | 관리자 / 워커 → Server | 제한적 | Kubernetes API |
| Kubelet | `10250/tcp` | 노드 간 | 내부 전용 | 노드/컨트롤 플레인 통신 |
| Flannel VXLAN | `8472/udp` | 노드 간 | 내부 전용 | Pod 네트워크 |
| Ingress HTTP | `80/tcp` | 외부 → App 계층 | 공개 가능 | 웹 진입 |
| Ingress HTTPS | `443/tcp` | 외부 → App 계층 | 공개 가능 | TLS 웹 진입 |

## 5. 목표 SG 설계안

### 5.1 1차 목표

초기 인프라 단계에서는 다음 구성이 현실적이다.

- `server` SG 1개
- `worker-shared` SG 1개

이 단계에서 역할 분리는 Kubernetes 라벨, taint, affinity로 제어한다.

### 5.2 확장 목표

후속 단계에서는 아래처럼 역할별 워커 SG 분리를 고려한다.

| SG | 대상 역할 | 주 용도 |
|----|-----------|--------|
| `server` | Server | API Server, control plane |
| `app` | App | Ingress 수신, 앱 서비스 |
| `metrics` | Metrics | Prometheus, Grafana |
| `logs-traces` | Logs-Traces | Loki, Tempo, OTel Collector |
| `db` | DB | PostgreSQL, Redis |
| `llm-obs` | LLM-Obs | Langfuse Web + Worker |
| `clickhouse` | ClickHouse | ClickHouse 전용 |

## 6. 역할별 통신 방향

| 출발 | 도착 | 포트 | 성격 |
|------|------|------|------|
| 관리자 IP | 모든 노드 | `22/tcp` | 운영 접근 |
| 관리자 IP | Server | `6443/tcp` | kubeconfig/API 접근 |
| 모든 워커 | Server | `6443/tcp` | 클러스터 조인 및 API 통신 |
| 모든 노드 | 모든 노드 | `8472/udp` | Flannel VXLAN |
| 모든 노드 | 모든 노드 | `10250/tcp` | kubelet 통신 |
| 외부 사용자 | App 계층 | `80/tcp`, `443/tcp` | 웹 진입점 |

## 7. 데이터 계층 포트 원칙

아래 포트는 현재 외부 공개 대상이 아니며, 필요 시 내부 SG 참조 기반으로만 열어야 한다.

| 서비스 | 기본 포트 | 원칙 |
|--------|----------|------|
| PostgreSQL | `5432/tcp` | App, LLM-Obs 등 필요한 내부 워크로드에만 허용 |
| Redis | `6379/tcp` | Langfuse 및 내부 의존성에만 허용 |
| ClickHouse HTTP | `8123/tcp` | 내부 의존성 한정 |
| ClickHouse Native | `9000/tcp` | 내부 의존성 한정 |
| Grafana | `3000/tcp` | 직접 외부 공개 대신 Ingress 뒤 배치 우선 |

## 8. 현재 미결정 사항

아래는 아직 확정되지 않았다.

- `80/443`을 App 노드에 직접 열지, 별도 ingress 전용 노드나 LoadBalancer 계층으로 둘지
- 역할별 SG를 실제로 분리할지, `worker-shared`를 유지할지
- DB 계층 포트를 노드 레벨에서 열지, Kubernetes 네트워크 정책으로만 제어할지
- Bastion 없이 직접 SSH 접근을 유지할지
- GitHub Actions에서 어떤 경로로 노드에 접근할지

## 9. 적용 원칙

- 외부 공개 포트는 최소화한다.
- 내부 통신은 가능하면 SG 참조 기반으로 제한한다.
- Terraform 현재 구현은 부트스트랩용이며, 이 문서의 목표 상태를 아직 전부 구현하지 않는다.
- 실제 SG 구현 전에는 IAM 권한으로 SG 생성/수정이 가능한지 먼저 확인한다.

## 10. 다음 단계

1. `server + worker-shared`로 시작할지 여부 확정
2. `80/443` 노출 방식 확정
3. 역할별 SG 분리 필요성 판단
4. Terraform 모듈 확장 여부 결정
