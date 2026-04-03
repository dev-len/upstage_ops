# [ADR-006] K3S 7노드 역할 분리 토폴로지 채택

- **상태**: Accepted
- **날짜**: 2026-04-03
- **대체 ADR**: ADR-003

## 맥락 (Context)

기존 ADR-003은 K3S 멀티 노드 방향 자체는 맞았지만, `Obs 1대 + DB 1대` 수준의 단순 분리였다.
이후 관측 스택과 Langfuse 저장소 스택의 실제 메모리 요구량을 다시 검토한 결과, `t3.medium` 제약에서 기존 구성이 과밀하다고 판단했다.

- Prometheus, Grafana, Loki, Tempo, OTel Collector를 한 노드에 몰면 여유가 거의 없다
- PostgreSQL, ClickHouse, Redis를 한 노드에 묶으면 ClickHouse 때문에 메모리 위험이 커진다
- Langfuse v3 저장소 구조와 관측 스택을 함께 고려하면 더 세분화된 역할 분리가 필요하다

## 결정 (Decision)

K3S 클러스터는 **7노드 역할 분리 토폴로지**를 채택한다.

```
Server Node (1대)         — K3S 컨트롤 플레인
Agent: App (2대)          — 애플리케이션 서비스
Agent: Metrics (1대)      — Prometheus, Grafana
Agent: Logs-Traces (1대)  — Loki, Tempo, OTel Collector
Agent: DB (1대)           — PostgreSQL, Redis
Agent: LLM-Obs (1대)      — Langfuse Web + Worker
Agent: ClickHouse (1대)   — ClickHouse 전용
```

## 검토한 대안 (Alternatives Considered)

### 대안 1: 기존 5노드 분리형

- **장점**: 비용이 더 낮고 토폴로지가 단순하다
- **단점**: 관측과 저장소 계층 모두 `t3.medium`에서 과밀하다
- **탈락 사유**: 운영 안정성 기준을 만족하기 어렵다

### 대안 2: 6노드 절충형

ClickHouse를 DB 노드에 통합하고 관측만 분리한다.

- **장점**: 7노드보다 비용이 낮다
- **단점**: DB 노드의 메모리 경합이 크고 ClickHouse 튜닝 의존도가 높다
- **탈락 사유**: 초기 기준선은 비용보다 안정성을 우선한다

## 결과 (Consequences)

### 긍정적

- 관측과 저장소 계층의 리소스 경합을 크게 줄인다
- 장애 영향 범위를 더 작은 역할 단위로 격리할 수 있다
- Node Affinity, Taint/Toleration, 역할 기반 스케줄링을 더 명확히 적용할 수 있다

### 부정적

- EC2 인스턴스 수와 비용이 증가한다
- 노드 라벨링, 스케줄링, 스토리지 운영 복잡도가 높아진다

### 리스크

- AWS 학습 계정의 EC2 동시 실행 제한 또는 vCPU limit에 걸릴 수 있다
  - 대응: 착수 전 계정 한도를 확인한다
- ClickHouse 전용 노드도 메모리 튜닝이 필요할 수 있다
  - 대응: 메모리 상한, retention, 디스크 전략을 초기부터 제어한다

## 참고 (References)

- K3S Architecture: https://docs.k3s.io/architecture
- K3S Requirements: https://docs.k3s.io/installation/requirements
- Kubernetes Node Affinity: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/
