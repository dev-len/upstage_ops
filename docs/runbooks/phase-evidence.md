# Phase Evidence Checklist

- 문서 상태: Draft
- 작성일: 2026-04-06
- 목적: PRD Phase 2~7 완료 판단에 필요한 최소 증거를 한 곳에 모은다.

## Phase 2

- `terragrunt plan` 성공 로그
- `terragrunt output -json` 결과
- 실제 사용한 `inputs.hcl` 값에서 민감값을 제거한 스냅샷

## Phase 3

- `kubectl get nodes -o wide`
- `kubectl get nodes --show-labels`
- server/worker bootstrap 실행 로그

## Phase 4

- `kubectl get pods -n monitoring`
- Grafana data source 연결 확인 화면 또는 명령 결과
- Prometheus, Loki, Tempo 데이터 조회 증거

## Phase 5

- `kubectl rollout status deployment/sample-httpbin -n sample-app`
- `kubectl get ingress -n sample-app`
- `curl` 200 응답 로그

## Phase 6

- AI Gateway 검토 문서 링크
- 도입 여부와 범위 결정 기록

## Phase 7

- `kubectl get pods -n langfuse`
- Langfuse 접속 확인
- 테스트 LLM trace 생성 및 조회 증거

## 공통

- 실행 불가 항목은 `blocked`로 기록한다.
- IAM 또는 실행 환경 제약은 실패와 분리한다.
- 증거 파일은 `artifacts/evidence/` 아래에 저장하는 것을 기본으로 둔다.
- 요약 파일은 `artifacts/evidence/summary.md`를 기본 템플릿으로 사용한다.
- 빠른 수집은 `bash scripts/capture-phase-evidence.sh`로 시작한다.
