# [ADR-007] Envoy AI Gateway 검토 범위를 일반 ingress와 분리한다

- **상태**: Accepted
- **날짜**: 2026-04-06

## 맥락 (Context)

PRD는 Phase 6에서 Envoy AI Gateway 검토 문서를 요구한다. 현재 저장소는 K3S ingress, observability, Langfuse, bastion 운영 경계까지는 정리됐지만 AI Gateway의 실제 도입 범위는 아직 남아 있었다.

- 현재 일반 웹 트래픽 진입점은 K3S 기본 ingress(Traefik) 기준으로 설명되어 있다
- LLM 관련 관측은 Langfuse와 OTel/Tempo로 분리되어 있다
- 지금 단계에서 필요한 것은 곧바로 배포를 강제하는 결정이 아니라, 어디까지를 검토 범위로 보고 무엇을 후속으로 미루는지의 경계다

## 결정 (Decision)

Envoy AI Gateway는 이번 baseline에서 **즉시 배포 대상이 아니라 검토 대상**으로 둔다.

구체적인 경계는 아래와 같다.

1. 일반 웹 트래픽 ingress는 계속 Traefik이 맡는다
2. Envoy AI Gateway는 AI/LLM 요청 제어 계층 후보로만 다룬다
3. Phase 6 산출물은 배포 구현이 아니라 요구사항, 배치 위치, 운영 리스크를 정리한 문서다
4. 실제 도입 판단은 샘플 앱 배포, observability, Langfuse 실가동 증거 확보 이후로 미룬다

## 검토 범위 (Evaluation Scope)

Phase 6에서 최소로 검토할 항목은 아래다.

- 배치 위치
  - app pod 내부 sidecar가 아니라 cluster 외곽의 별도 gateway 계층으로 둘지
- 역할 경계
  - Traefik과 중복하지 않고 어떤 요청만 AI Gateway를 통과시킬지
- 정책 후보
  - provider routing
  - auth / key management
  - rate limiting
  - retry / timeout
  - request / response logging
- 관측 연계
  - AI Gateway 로그를 OTel Collector -> Loki로 보낼 수 있는지
  - gateway trace를 Tempo와 Langfuse correlation에 활용할 수 있는지
- 운영 비용
  - `t3.medium` 제약에서 별도 gateway pod/노드가 필요한지

## 검토한 대안 (Alternatives Considered)

### 대안 1: 지금 바로 Envoy AI Gateway를 배포 대상으로 확정

- **장점**: AI 트래픽 제어 구조를 더 빨리 실습할 수 있다
- **단점**: 아직 샘플 앱, observability, Langfuse도 실가동 증거가 부족한 상태에서 새 운영 면을 추가하게 된다
- **탈락 사유**: baseline 증거 확보보다 의사결정 범위가 먼저 커진다

### 대안 2: AI Gateway 검토 자체를 Phase 8 이후로 연기

- **장점**: 현재 구현 범위가 더 단순해진다
- **단점**: PRD의 Phase 6 완료 기준을 충족하지 못하고, 일반 ingress와 AI 경로의 경계도 계속 모호하게 남는다
- **탈락 사유**: 이번 단계에서 문서 수준의 경계 고정은 필요하다

## 결과 (Consequences)

### 긍정적

- PRD의 Phase 6 완료 기준을 문서 기준으로 충족할 수 있다
- Traefik과 Envoy AI Gateway의 역할이 섞이지 않는다
- 실제 도입 판단 시 필요한 체크리스트를 미리 고정할 수 있다

### 부정적

- gateway 도입 여부는 여전히 미결정으로 남는다
- 실제 manifest나 Helm chart는 이번 결정만으로는 추가되지 않는다

### 리스크

- 문서만 있고 실험이 늦어지면 향후 검토가 다시 추상적으로 흐를 수 있다
  - 대응: 샘플 앱과 Langfuse가 안정화된 후 gateway proof-of-concept를 별도 lane으로 분리한다

## 후속 작업 (Next Steps)

- 샘플 앱의 외부 응답 검증이 끝나면 AI 요청 경로용 별도 demo workload를 설계한다
- observability와 Langfuse trace가 확보되면 gateway trace correlation 가능성을 검토한다
- 필요 시 `kubernetes/gateway/` 또는 `deployments/gateway/` 레이어를 새 lane으로 추가한다

## 참고 (References)

- [PRD](../PRD.md)
- [아키텍처 문서](../architecture.md)
- [ADR-001](./001-adopt-hybrid-telemetry-collection.md)
- [ADR-005](./005-adopt-langfuse-v3-storage-topology.md)
