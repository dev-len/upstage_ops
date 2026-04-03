# Observability Deployment Assets

이 디렉터리는 T6 lane의 observability 배치 자산을 담는다.

## 목적

- Metrics, Logs-Traces, DB, LLM-Obs, ClickHouse 책임을 분리한다.
- T5 bootstrap lane의 node labels / taints를 그대로 사용한다.
- 비밀값은 `existingSecret` 또는 별도 Secret manifest로 넘긴다.

## Role Mapping

- metrics node
  - Prometheus
  - Grafana
- logs-traces node
  - Loki
  - Tempo
  - OpenTelemetry Collector
- db node
  - PostgreSQL
  - Redis
- llm-obs node
  - Langfuse web
  - Langfuse worker
- clickhouse node
  - ClickHouse

## Scheduling Contract

T5 labels:

- `topology.k3s.io/role=metrics`
- `topology.k3s.io/role=logs-traces`
- `topology.k3s.io/role=db`
- `topology.k3s.io/role=llm-obs`
- `topology.k3s.io/role=clickhouse`

T5 taints:

- `dedicated=metrics:NoSchedule`
- `dedicated=logs-traces:NoSchedule`
- `dedicated=db:NoSchedule`
- `dedicated=llm-obs:NoSchedule`
- `dedicated=clickhouse:NoSchedule`

Each values file below uses those labels and tolerations directly.
