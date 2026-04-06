# Task Orchestration

- 문서 상태: Draft
- 작성일: 2026-04-03
- 목적: `docs/tasks`를 subagent 멀티 태스크 작업의 기준 문서 폴더로 사용한다.

## 사용 원칙

- 이 폴더의 문서는 subagent에 바로 위임 가능한 작업 정의를 담는다.
- 전체 방향성, 공통 제약, lane 분할 기준은 먼저 이 폴더 문서에서 고정한다.
- 실제 병렬 작업은 각 task 문서를 기준으로 시작한다.

## 시작점

- 전체 작업 기준 문서: [subagent-task-orchestration.md](/Users/len/Desktop/project/k8s/docs/tasks/subagent-task-orchestration.md)
- skill 검토 문서: [skills-plan.md](/Users/len/Desktop/project/k8s/docs/tasks/skills-plan.md)
- K3S bootstrap 기준: [k3s-bootstrap-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/k3s-bootstrap-baseline.md)
- 검증 기준 문서: [validation-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/validation-baseline.md)
- IaC 실행 경로: [iac-pipeline.md](/Users/len/Desktop/project/k8s/docs/tasks/iac-pipeline.md)
- Terragrunt 진입점 문서: [README.md](/Users/len/Desktop/project/k8s/terragrunt/README.md)
- Cluster bring-up runbook: [cluster-bring-up.md](/Users/len/Desktop/project/k8s/docs/runbooks/cluster-bring-up.md)
- Workload rollout runbook: [workload-rollout.md](/Users/len/Desktop/project/k8s/docs/runbooks/workload-rollout.md)
- Phase evidence checklist: [phase-evidence.md](/Users/len/Desktop/project/k8s/docs/runbooks/phase-evidence.md)

## 사용 원칙

- 각 lane은 공통 검증 기준을 먼저 확인한다.
- 실행 가능한 검증과 환경상 불가능한 검증을 분리해서 기록한다.
- Terraform, Kubernetes, CI/CD, 문서 작업은 모두 같은 리뷰 기준을 공유한다.
- 현재 구현 기준선은 Terragrunt, SG bootstrap, EC2 baseline, storage, K3S bootstrap, observability/Langfuse values, IaC pipeline 문서, `kubernetes/` workload layer까지 포함한다.
