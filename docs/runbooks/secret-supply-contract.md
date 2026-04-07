# Secret Supply Contract

- 문서 상태: Draft
- 작성일: 2026-04-07
- 목적: CloudShell 원클릭 부트스트랩에서 사용하는 실제 Kubernetes Secret 입력 계약을 고정한다.

## 1. 기본 원칙

- 실제 Secret 값은 Git에 커밋하지 않는다.
- one-shot 실행은 CloudShell 로컬 YAML 파일만 읽는다.
- placeholder 값 `CHANGE_ME`가 남아 있으면 실행을 중단한다.
- Secret은 workload apply 전에 먼저 `kubectl apply -f`로 적용한다.

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
