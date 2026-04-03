# [ADR-003] K3S 멀티 노드 풀스택 구성

- **상태**: Superseded
- **날짜**: 2026-04-02
- **대체 ADR**: ADR-006

## 맥락 (Context)

K3S 클러스터의 노드 구성 전략을 결정해야 한다.

- EC2 인스턴스는 `t3.medium`(2 vCPU, 4GB RAM)으로 제한되지만 인스턴스 수는 제한 없음
- 앱 서비스, 텔레메트리 스택(Prometheus/Loki/Tempo/Grafana), LLM 관측(Langfuse + PostgreSQL)을 모두 운영해야 함
- 단일 노드에 모든 워크로드를 넣으면 4GB로는 리소스 부족 확실
- 학습 목적으로 멀티 노드 K3S 운영 경험을 쌓고 싶음

## 결정 (Decision)

**풀스택 멀티 노드** 구성으로 역할별 노드를 분리한다.

```
Server Node (1대)     — K3S 컨트롤 플레인 (etcd, API Server, Scheduler)
Agent: App (1대~)     — 애플리케이션 서비스 (Next.js / FastAPI)
Agent: Obs (1대)      — 관측 스택 (Prometheus, Grafana, Loki, Tempo, OTel)
Agent: DB (1대)       — 데이터베이스 (PostgreSQL for Langfuse)
Agent: LLM-Obs (1대)  — LLM 관측 (Langfuse)
```

> 최종 노드 수는 서비스 스택 확정 후 조정한다.
> 최소 서버 1 + 에이전트 2~3 에서 시작하여 필요 시 확장.

## 검토한 대안 (Alternatives Considered)

### 대안 1: 단일 노드 (All-in-One)

서버 겸 워커로 모든 워크로드를 한 노드에서 운영.

- **장점**: 구성 가장 단순, EC2 비용 최소
- **단점**: 4GB RAM으로는 관측 스택+앱+DB 동시 운영 불가능에 가까움
- **탈락 사유**: 리소스 물리적 한계

### 대안 2: 미니멀 (서버 1 + 에이전트 1)

서버와 에이전트 2대로 앱/관측을 나눠서 운영.

- **장점**: EC2 비용 절약, 구성 비교적 단순
- **단점**: 관측 스택과 앱이 같은 노드에 동거 시 리소스 경합 발생, DB 분리 불가
- **탈락 사유**: 학습 목적에서 노드 역할 분리를 경험하는 것이 가치 있고, 인스턴스 수 제한이 없으므로 굳이 절약할 이유 없음

### 대안 3: 분리형 (서버 1 + 에이전트 2~3)

관측용/앱용 노드 분리.

- **장점**: 적절한 균형, 운영 안정성 확보
- **단점**: DB와 LLM 관측이 다른 워크로드와 동거해야 할 수 있음
- **탈락 사유**: 나쁘지 않지만 학습 목적에서 더 세분화된 분리를 원함

## 결과 (Consequences)

### 긍정적

- 역할별 노드 분리로 리소스 경합 최소화
- K8S의 Node Affinity, Taint/Toleration 등 스케줄링 개념 실습 가능
- 노드 장애 시 영향 범위가 역할 단위로 격리
- 실제 프로덕션 환경과 유사한 구성 경험

### 부정적

- EC2 인스턴스 4~5대 운영으로 AWS 비용 증가
- 노드 간 네트워크 관리 복잡도 증가
- Terraform 코드 복잡도 증가

### 리스크

- AWS 학습용 계정의 EC2 동시 실행 제한에 걸릴 가능성
  - 대응: 사전에 계정의 EC2 running limit 확인
- 노드 수가 많아지면 K3S 클러스터 관리 복잡도 증가
  - 대응: Phase별로 점진적으로 노드 추가

## 참고 (References)

- K3S Architecture: https://docs.k3s.io/architecture
- K3S Requirements: https://docs.k3s.io/installation/requirements
- Kubernetes Node Affinity: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
