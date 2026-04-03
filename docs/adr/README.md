# Architecture Decision Records (ADR)

## ADR이란?

ADR(Architecture Decision Record)은 프로젝트에서 내린 **중요한 아키텍처 결정**을 기록하는 문서이다.
왜 그 결정을 내렸는지, 어떤 대안을 검토했는지, 어떤 맥락에서 그런 선택을 했는지를 남겨서
미래의 팀원이나 본인이 "왜 이렇게 했지?"를 이해할 수 있게 한다.

## 작성 규칙

### 파일명 규칙

```
YYYY-MM-DD-short-decision.md
```

- `YYYY-MM-DD`: 결정 날짜
- `short-decision`: 결정 내용을 드러내는 짧은 kebab-case 영문
- 파일명은 주제가 아니라 "무엇을 결정했는지"가 드러나야 한다
- 예시: `2026-04-03-adopt-k3s-over-kubernetes.md`

### 상태 (Status)

| 상태 | 설명 |
|------|------|
| **Proposed** | 제안됨, 아직 결정되지 않음 |
| **Accepted** | 팀에서 수용한 결정 |
| **Deprecated** | 더 이상 유효하지 않은 결정 |
| **Superseded** | 다른 ADR로 대체됨 |

- 상태는 위 값 중 하나만 사용한다
- 다른 ADR로 대체된 경우 `상태: Superseded`로 기록하고, 문서 메타데이터에 대체된 ADR 파일이나 제목을 명시한다

### 작성 시점

다음과 같은 경우 ADR을 작성한다:

- 기술 스택 선택 (언어, 프레임워크, 인프라 도구)
- 아키텍처 패턴 결정 (모놀리스 vs 마이크로서비스, 수집 방식 등)
- 외부 서비스/도구 도입
- 기존 결정을 변경할 때 (기존 ADR을 Superseded 처리)

### 작성하지 않는 것

- 단순 버그 수정, 코드 스타일 변경
- 이미 팀 표준으로 정해진 사항의 반복
- 되돌리기 쉬운 사소한 선택

### 원칙

1. **간결하게**: 1~2페이지 이내로 작성한다
2. **맥락 중심**: "무엇을" 보다 "왜"를 중심으로 쓴다
3. **불변**: 한번 Accepted된 ADR의 본문은 수정하지 않는다. 변경이 필요하면 새 ADR을 작성하고 기존 것을 Superseded 처리한다
4. **대안 기록**: 선택하지 않은 대안도 반드시 기록하여 동일한 논의를 반복하지 않는다

## 템플릿

[ADR 템플릿](./000-template.md)을 복사하여 새 ADR을 작성한다.

### 작성 절차

1. [`000-template.md`](./000-template.md)를 복사해 새 파일을 만든다
2. 파일명을 `YYYY-MM-DD-short-decision.md` 형식으로 정한다
3. 메타데이터와 본문을 작성한다
4. 대체 결정이라면 기존 ADR 상태를 `Superseded`로 바꾸고 `대체 ADR`을 채운다
5. 이 README의 목록 표를 갱신한다

## 목록

| # | 제목 | 상태 | 날짜 |
|---|------|------|------|
| 001 | [텔레메트리 수집 하이브리드 방식 채택](./001-adopt-hybrid-telemetry-collection.md) | Accepted | 2026-04-02 |
| 002 | [LLM 관측 도구로 Langfuse 선택](./002-select-langfuse-for-llm-observability.md) | Superseded | 2026-04-02 |
| 003 | [K3S 멀티 노드 풀스택 구성](./003-adopt-k3s-multi-node-topology.md) | Superseded | 2026-04-02 |
| 004 | [Grafana 단일 시각화 플랫폼 채택](./004-standardize-on-grafana-for-visualization.md) | Accepted | 2026-04-02 |
| 005 | [Langfuse v3 저장소 토폴로지 채택](./005-adopt-langfuse-v3-storage-topology.md) | Accepted | 2026-04-03 |
| 006 | [K3S 7노드 역할 분리 토폴로지 채택](./006-adopt-k3s-seven-node-topology.md) | Accepted | 2026-04-03 |
| 2026-04-03 | [학습 계정에서 수동 bootstrap SG 주입 경로 채택](./2026-04-03-adopt-manual-bootstrap-sg-in-learning-account.md) | Accepted | 2026-04-03 |
| 2026-04-04 | [private fleet 운영을 위한 bastion 진입점 채택](./2026-04-04-adopt-bastion-entrypoint-for-private-fleet.md) | Accepted | 2026-04-04 |
