# [ADR-005] Langfuse v3 저장소 토폴로지 채택

- **상태**: Accepted
- **날짜**: 2026-04-03
- **대체 ADR**: ADR-002

## 맥락 (Context)

기존 ADR-002는 Langfuse를 선택하는 결정만 담고 있으며, 저장소 구성을 `Langfuse + PostgreSQL` 수준으로 단순화했다.
현재 프로젝트는 Langfuse v3 기준으로 self-hosting을 전제로 설계를 진행하고 있고, 운영 저장소 구성이 더 구체화되었다.

- Langfuse v3는 PostgreSQL 외에 ClickHouse, Redis를 포함한 저장소 계층을 전제로 본다
- `t3.medium` 제약 아래에서 Langfuse 애플리케이션 계층과 저장소 계층을 분리해 운영 안정성을 확보해야 한다
- 아키텍처 문서와 PRD는 이미 Langfuse 저장소 스택을 `PostgreSQL + ClickHouse + Redis` 기준으로 정리하고 있다

## 결정 (Decision)

Langfuse는 **v3 저장소 토폴로지**를 기준으로 self-hosting 한다.

- 애플리케이션 계층: `Langfuse Web + Worker`
- 저장소 계층: `PostgreSQL + ClickHouse + Redis`
- PostgreSQL은 앱 메타데이터와 Langfuse metadata를 공용 인스턴스에서 분리 운영할 수 있다
- ClickHouse는 전용 노드에 분리 배치한다
- Redis는 DB 노드에 함께 배치한다

## 검토한 대안 (Alternatives Considered)

### 대안 1: 기존 ADR-002 수준 유지

Langfuse를 도구 선택 결정으로만 남기고 저장소 세부 구조는 별도 결정 없이 운영한다.

- **장점**: 문서 수정 범위가 작다
- **단점**: PRD, 아키텍처 문서, 실제 배포 설계와 ADR 사이에 불일치가 남는다
- **탈락 사유**: 운영 기준 문서가 서로 다른 모델을 가리키게 되어 혼선이 생긴다

### 대안 2: ClickHouse를 DB 노드에 통합

- **장점**: 노드 수를 줄일 수 있다
- **단점**: `t3.medium`에서 PostgreSQL, Redis, ClickHouse 동거 시 메모리 경합과 OOM 위험이 높다
- **탈락 사유**: 현재 기준선은 운영 안정성 우선이다

## 결과 (Consequences)

### 긍정적

- Langfuse 운영 구조가 PRD와 아키텍처 문서와 일치한다
- Langfuse 앱 계층과 저장소 계층을 분리해 장애 범위를 줄일 수 있다
- ClickHouse를 전용 노드로 분리해 메모리 압박을 완화한다

### 부정적

- 저장소 운영 복잡도가 증가한다
- ClickHouse, Redis까지 포함되어 문서와 배포 구성이 더 복잡해진다

### 리스크

- ClickHouse 운영 경험이 부족하면 튜닝과 장애 대응 난도가 높다
  - 대응: retention, 메모리 상한, 스토리지 전략을 초기부터 문서화한다
- PostgreSQL 공용 운영 시 앱 DB와 Langfuse metadata 간 자원 경쟁이 생길 수 있다
  - 대응: DB/사용자/권한 분리와 리소스 모니터링을 기본 전제로 둔다

## 참고 (References)

- Langfuse Self-Hosting: https://langfuse.com/docs/deployment/self-host
- Langfuse Python SDK: https://langfuse.com/docs/sdk/python
- Langfuse JS/TS SDK: https://langfuse.com/docs/sdk/typescript
