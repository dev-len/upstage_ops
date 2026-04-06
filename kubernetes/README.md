# Kubernetes Workload Layer

이 디렉터리는 Terraform이 만든 EC2/K3S baseline 위에 올리는 선언형 Kubernetes 자산을 담는다.

## 목적

- 샘플 앱 배포 진입점을 제공한다.
- observability / Langfuse lane의 namespace, secret 계약, 네트워크 경계를 고정한다.
- `kubectl apply -k` 기준의 최소 배포 경로를 제공한다.

## 구성

- `apps/sample-httpbin`
  - 샘플 앱 배포, Service, Ingress, NetworkPolicy
- `platform/observability`
  - observability namespace, helm values ConfigMap, secret placeholder, NetworkPolicy
- `platform/langfuse`
  - langfuse namespace, secret placeholder, NetworkPolicy

## 적용 순서

1. `kubectl apply -k kubernetes/platform/observability`
2. `kubectl apply -k kubernetes/platform/langfuse`
3. `kubectl apply -k kubernetes/apps/sample-httpbin`

Helm chart 배포 자체는 이 디렉터리가 직접 수행하지 않는다. Helm values는 기존
`deployments/` 자산을 ConfigMap으로 고정해 두고, 실제 install/upgrade 절차는
[`docs/runbooks/workload-rollout.md`](/Users/len/Desktop/project/k8s/docs/runbooks/workload-rollout.md)를 따른다.
