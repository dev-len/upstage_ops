# [ADR-004] Grafana 단일 시각화 플랫폼 채택

- **상태**: Accepted
- **날짜**: 2026-04-02

## 맥락 (Context)

텔레메트리 시각화 도구를 선택해야 한다.

- 메트릭(Prometheus), 로그(Loki), 트레이스(Tempo) 세 가지 백엔드를 사용한다
- 각 백엔드마다 별도 UI를 쓸 수도 있고, 하나로 통합할 수도 있다
- 운영 편의성과 학습 효율을 고려해야 한다

## 결정 (Decision)

**Grafana**를 단일 시각화 플랫폼으로 사용한다.

- Prometheus → Grafana Data Source (메트릭 대시보드)
- Loki → Grafana Data Source (로그 탐색)
- Tempo → Grafana Data Source (트레이스 뷰)
- 세 신호 간 상관 분석(Correlation)도 Grafana 내에서 수행

## 검토한 대안 (Alternatives Considered)

### 대안 1: ELK Stack (Elasticsearch + Kibana)

로그를 Elasticsearch에 저장하고 Kibana로 시각화.

- **장점**: 강력한 전문 검색(Full-text search), Kibana 시각화 풍부, 업계에서 널리 사용
- **단점**: Elasticsearch 메모리 요구량 매우 높음(최소 2GB+), Kibana도 별도 리소스 필요, Grafana와 이중 UI 운영 부담
- **탈락 사유**: t3.medium(4GB) 환경에서 Elasticsearch 운영 비현실적, 별도 시각화 도구를 운영하면 관리 포인트 증가

### 대안 2: 도구별 개별 UI

Prometheus UI + Loki(LogCLI) + Tempo(Jaeger UI) 각각 사용.

- **장점**: 추가 도구 없이 각 백엔드의 기본 UI 사용 가능
- **단점**: 3개 UI를 오가며 작업해야 함, 신호 간 상관 분석 불가, 통합 대시보드 구성 불가
- **탈락 사유**: 운영 효율성 크게 떨어짐, 통합 뷰 필요

## 결과 (Consequences)

### 긍정적

- 로그/메트릭/트레이스를 하나의 UI에서 통합 조회 가능
- Trace → Log, Metric → Trace 등 신호 간 상관 분석(Correlation) 가능
- Grafana 대시보드 템플릿(커뮤니티) 활용으로 빠른 구축 가능
- 하나의 도구만 학습하면 세 가지 신호를 모두 다룰 수 있음

### 부정적

- Grafana 자체의 리소스 소비 (~256MB+)
- Grafana 설정/대시보드 관리가 필요 (JSON 프로비저닝 또는 UI 수동 설정)

### 리스크

- Grafana 단일 장애 지점(SPOF)
  - 대응: Grafana 대시보드를 JSON으로 Git 관리하여 빠른 복구 가능
- 커스텀 대시보드 구성에 시간 투자 필요
  - 대응: 커뮤니티 대시보드 (Node Exporter Full, K8s Cluster 등) 활용

## 참고 (References)

- Grafana Data Sources: https://grafana.com/docs/grafana/latest/datasources/
- Grafana Loki 연동: https://grafana.com/docs/grafana/latest/datasources/loki/
- Grafana Tempo 연동: https://grafana.com/docs/grafana/latest/datasources/tempo/
- Grafana 커뮤니티 대시보드: https://grafana.com/grafana/dashboards/
