# Secret Supply Contract

- 문서 상태: Draft
- 작성일: 2026-04-07
- 목적: CloudShell 원클릭 부트스트랩에서 사용하는 실제 Kubernetes Secret 입력 계약을 고정한다.

## 1. 기본 원칙

- 실제 Secret 값은 Git에 커밋하지 않는다.
- one-shot 실행은 CloudShell 로컬 YAML 파일만 읽는다.
- placeholder 값 `CHANGE_ME`가 남아 있으면 실행을 중단한다.
- Secret은 workload apply 전에 먼저 `kubectl apply -f`로 적용한다.
- Langfuse의 `host` 값은 EC2 private/public IP를 직접 적는 계약이 아니다.
- Langfuse의 `host` 값은 같은 K3S 클러스터 안에서 PostgreSQL, Redis, ClickHouse가 노출하는 Kubernetes Service DNS를 가리켜야 한다.
- 저장소 계층은 Langfuse 앱보다 먼저 부트스트랩되어야 하며, Langfuse는 그 저장소 Service에 연결되는 구조를 전제로 한다.

## 2. 파일 위치

실제 파일:

- `.cloudshell/secrets/observability.secret.yaml`
- `.cloudshell/secrets/langfuse.secret.yaml`

예시 파일:

- `.cloudshell/secrets/observability.secret.example.yaml`
- `.cloudshell/secrets/langfuse.secret.example.yaml`

## 3. 필수 Secret 이름

observability:

- `grafana-admin-secret`

langfuse:

- `langfuse-app-secret`
- `langfuse-db-secret`
- `langfuse-redis-secret`
- `langfuse-clickhouse-secret`

## 4. 검증 규칙

one-shot 스크립트는 아래를 모두 확인한다.

- 파일이 존재해야 한다.
- YAML에 `CHANGE_ME`가 남아 있으면 안 된다.
- Secret `metadata.name`이 필수 이름과 일치해야 한다.
- Secret `metadata.namespace`는 아래와 일치해야 한다.
  - observability: `monitoring`
  - langfuse: `langfuse`

이 규칙을 만족하지 않으면 배포를 중단한다.

## 5. 운영 메모

- Secret 파일은 CloudShell 세션마다 필요한 위치에 다시 준비할 수 있어야 한다.
- Secret 값 변경 후에는 one-shot을 다시 실행해 `kubectl apply -f`로 반영한다.
- Secret 파일 경로는 `.gitignore`에 포함되며, 예시 파일만 저장소에 남긴다.
- `LANGFUSE_SALT`, `NEXTAUTH_SECRET`는 CloudShell에서 `openssl rand -hex 32` 등으로 생성한 랜덤 문자열을 사용한다.
- `langfuse-*-secret`의 `host`는 "인프라 apply 후 확인한 노드 IP"가 아니라 "클러스터 내부 Service 이름"을 넣어야 한다.
- 예시:
  - PostgreSQL: `postgresql.langfuse.svc.cluster.local`
  - Redis: `redis.langfuse.svc.cluster.local`
  - ClickHouse: `clickhouse.langfuse.svc.cluster.local`
- 실제 Service 이름과 namespace는 저장소 계층 manifest/Helm 계약에 맞춰 최종 확정해야 한다.
- 현재 baseline 예시 파일은 아래 FQDN을 기본값으로 사용한다.
  - PostgreSQL: `postgresql.langfuse.svc.cluster.local`
  - Redis: `redis.langfuse.svc.cluster.local`
  - ClickHouse: `clickhouse.langfuse.svc.cluster.local`
