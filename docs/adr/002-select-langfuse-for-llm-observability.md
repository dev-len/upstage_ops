# [ADR-002] LLM 관측 도구로 Langfuse 선택

- **상태**: Accepted
- **날짜**: 2026-04-02

## 맥락 (Context)

팀에서 LLM을 활용한 서비스를 개발하고 있다.
LLM 호출에 대한 관측(트레이싱, 비용 추적, 프롬프트 관리)이 필요하며, 셀프 호스팅 가능한 도구를 선택해야 한다.

- AWS 학습용 계정이라 외부 SaaS에 대한 비용 지출을 최소화하고 싶다
- K3S 클러스터 내에 셀프 호스팅으로 운영해야 한다
- 서비스 스택은 Next.js(Node.js) 또는 FastAPI(Python) 예정

## 결정 (Decision)

**Langfuse**를 셀프 호스팅하여 LLM 관측 도구로 사용한다.

- K3S 클러스터 내에 Langfuse 서버 + PostgreSQL 배포
- 앱에서 Langfuse SDK로 LLM 호출 트레이싱

## 검토한 대안 (Alternatives Considered)

### 대안 1: Arize Phoenix

- **장점**: 로컬 실행 매우 간편, 가볍다, 트레이싱 중심으로 빠른 디버깅 가능
- **단점**: 프롬프트 버전 관리 기능 약함, 프로덕션 셀프 호스팅 성숙도가 Langfuse보다 낮음, 비용 추적 기능 제한적
- **탈락 사유**: 프로젝트 규모에서 프롬프트 관리와 비용 추적이 중요한데 이 부분이 약함

### 대안 2: LangSmith

- **장점**: LangChain 에코시스템 네이티브 통합, 기능 풍부
- **단점**: 셀프 호스팅 불가 (SaaS Only), 비용 발생, LangChain 종속성
- **탈락 사유**: 셀프 호스팅 필수 요구사항을 충족하지 못함

### 대안 3: OpenLIT

- **장점**: OTel 네이티브, GPU/인프라 모니터링 통합
- **단점**: 커뮤니티 규모 작음, 문서 부족, 프롬프트 관리 기능 미흡
- **탈락 사유**: 성숙도와 커뮤니티 지원 부족

## 결과 (Consequences)

### 긍정적

- LLM 호출의 전체 라이프사이클(입력→출력→비용)을 추적할 수 있다
- 프롬프트 버전 관리로 프롬프트 엔지니어링 이력을 관리할 수 있다
- 셀프 호스팅으로 데이터 주권을 유지하고 비용을 절감한다
- Python/Node.js SDK 모두 성숙하여 어떤 서비스 스택이든 연동 가능

### 부정적

- PostgreSQL 의존성이 추가되어 DB 운영 부담 증가
- Langfuse 서버 자체의 리소스 소비 (메모리 ~512MB 이상)

### 리스크

- t3.medium 노드에서 Langfuse + PostgreSQL을 함께 실행 시 메모리 부족 가능
  - 대응: 전용 노드 또는 DB 노드 분리
- Langfuse 버전 업그레이드 시 DB 마이그레이션 필요
  - 대응: EBS 볼륨 스냅샷으로 백업 후 업그레이드

## 참고 (References)

- Langfuse Self-Hosting: https://langfuse.com/docs/deployment/self-host
- Langfuse Python SDK: https://langfuse.com/docs/sdk/python
- Langfuse JS/TS SDK: https://langfuse.com/docs/sdk/typescript
