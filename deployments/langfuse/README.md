# Langfuse Deployment Assets

이 디렉터리는 Langfuse와 그 저장소 계층의 배치 기준을 담는다.

## Placement

- Langfuse web / worker
  - nodeSelector: `topology.k3s.io/role=llm-obs`
  - toleration: `dedicated=llm-obs:NoSchedule`
- PostgreSQL / Redis
  - nodeSelector: `topology.k3s.io/role=db`
  - toleration: `dedicated=db:NoSchedule`
- ClickHouse
  - nodeSelector: `topology.k3s.io/role=clickhouse`
  - toleration: `dedicated=clickhouse:NoSchedule`

## Secret placeholders

- `langfuse-app-secret`
- `langfuse-db-secret`
- `langfuse-redis-secret`
- `langfuse-clickhouse-secret`

Secret values are intentionally not committed here.
