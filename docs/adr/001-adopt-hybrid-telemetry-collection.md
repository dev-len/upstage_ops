# [ADR-001] 텔레메트리 수집 하이브리드 방식 채택

- **상태**: Accepted
- **날짜**: 2026-04-02

## 맥락 (Context)

LLM 서비스 운영을 위한 K3S 클러스터에 텔레메트리(Logs, Metrics, Traces)를 구축해야 한다.
수집 레이어를 어떻게 구성할지 결정이 필요하다.

- 메트릭(Metrics), 로그(Logs), 트레이스(Traces) 세 가지 신호를 모두 수집해야 한다
- 학습과 경험이 주 목적이므로 각 도구의 고유한 방식도 이해하고 싶다
- 동시에 업계 표준인 OpenTelemetry도 경험하고 싶다

## 결정 (Decision)

**하이브리드 수집 방식**을 채택한다.

- **Metrics**: Prometheus가 직접 pull 기반으로 scrape
- **Logs**: OpenTelemetry Collector가 수집 → Loki로 전송
- **Traces**: OpenTelemetry Collector가 수집 → Tempo로 전송

## 검토한 대안 (Alternatives Considered)

### 대안 1: 전체 OTel Collector 통합

모든 신호(logs, metrics, traces)를 OTel Collector로 통합 수집.

- **장점**: 단일 수집 레이어로 구성 단순, 백엔드 교체 용이
- **단점**: Prometheus의 pull 기반 아키텍처를 직접 경험할 수 없음, Prometheus의 서비스 디스커버리 등 핵심 기능을 OTel에 위임하게 됨
- **탈락 사유**: 학습 목적에서 Prometheus의 pull 모델을 직접 다뤄보는 것이 가치 있음

### 대안 2: 도구별 개별 수집 (OTel 미사용)

Promtail→Loki, Prometheus 직접 scrape, Jaeger SDK→Tempo 등 각각 개별 에이전트 사용.

- **장점**: 각 도구별 깊은 이해 가능, 구성이 직관적
- **단점**: 도구마다 별도 에이전트/설정 필요, 백엔드 교체 시 앱 코드 변경 필요, OTel 경험 불가
- **탈락 사유**: OTel은 업계 표준으로 자리잡고 있어 학습 가치가 높고, 경험해볼 필요가 있음

## 결과 (Consequences)

### 긍정적

- Prometheus의 pull 기반 메트릭 수집을 직접 학습할 수 있다 (PromQL, ServiceMonitor 등)
- OTel Collector의 파이프라인(Receiver → Processor → Exporter)을 실습할 수 있다
- 실무에서 가장 흔한 하이브리드 패턴을 경험한다

### 부정적

- 두 가지 수집 방식을 모두 관리해야 하므로 운영 복잡도 증가
- OTel Collector와 Prometheus 양쪽의 설정을 모두 이해해야 함

### 리스크

- t3.medium(4GB) 노드에서 OTel Collector DaemonSet + Prometheus가 함께 돌 때 리소스 부족 가능성
  - 대응: 관측 전용 노드 분리로 해소

## 참고 (References)

- OpenTelemetry Collector 문서: https://opentelemetry.io/docs/collector/
- Prometheus 서비스 디스커버리: https://prometheus.io/docs/prometheus/latest/configuration/configuration/
- Grafana LGTM 스택: https://grafana.com/about/grafana-stack/
