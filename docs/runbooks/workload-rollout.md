# Workload Rollout Runbook

- 문서 상태: Draft
- 작성일: 2026-04-06
- 목적: 샘플 앱, observability, Langfuse 배포 순서와 증거 수집 기준을 고정한다.

## 1. Namespace 및 계약 자산 적용

```bash
kubectl apply -k kubernetes/platform/observability
kubectl apply -k kubernetes/platform/langfuse
kubectl apply -k kubernetes/apps/sample-httpbin
```

이 단계는 namespace, secret placeholder, NetworkPolicy, Helm values ConfigMap을 만든다.
`kubernetes/platform/*/values/` 아래 파일은 `deployments/` values의 Kustomize-safe snapshot이다.
실제 Secret은 Kustomize에 포함하지 않고, [secret-supply-contract.md](/Users/len/Desktop/project/k8s/docs/runbooks/secret-supply-contract.md)의 CloudShell 로컬 YAML 파일을 먼저 적용한다.

## 2. Helm values 확인

observability values:

- `monitoring/observability-values`
- source files:
  - `grafana-values.yaml`
  - `loki-values.yaml`
  - `otel-collector-values.yaml`
  - `prometheus-values.yaml`
  - `tempo-values.yaml`

langfuse values:

- `langfuse/langfuse-values`
- source file:
  - `langfuse-values.yaml`

## 3. Observability 배포

one-shot 기준 chart 계약은 아래로 고정한다.

- Prometheus: `prometheus-community/prometheus`
- Grafana: `grafana/grafana`
- Loki: `grafana/loki`
- Tempo: `grafana/tempo`
- OpenTelemetry Collector: `open-telemetry/opentelemetry-collector`
- Langfuse: `langfuse/langfuse`

실제 install/upgrade는 [`helm-rollout.sh`](/Users/len/Desktop/project/k8s/scripts/helm-rollout.sh)와
[`cloudshell-workload-rollout.sh`](/Users/len/Desktop/project/k8s/scripts/cloudshell-workload-rollout.sh)가 수행한다.

최소 검증:

```bash
kubectl get ns monitoring
kubectl get configmap observability-values -n monitoring
kubectl get secret grafana-admin-secret -n monitoring
kubectl get networkpolicy -n monitoring
```

Helm 배포 후 검증:

```bash
kubectl get pods -n monitoring -o wide
kubectl get svc -n monitoring
```

## 4. Langfuse 배포

실제 chart install 전, 아래 secret 값을 CloudShell 로컬 YAML로 준비해 `kubectl apply -f` 해야 한다.

- `langfuse-app-secret`
- `langfuse-db-secret`
- `langfuse-redis-secret`
- `langfuse-clickhouse-secret`

최소 검증:

```bash
kubectl get ns langfuse
kubectl get configmap langfuse-values -n langfuse
kubectl get secrets -n langfuse
kubectl get networkpolicy -n langfuse
```

배포 후 검증:

```bash
kubectl get pods -n langfuse -o wide
kubectl get svc -n langfuse
```

## 5. 샘플 앱 검증

```bash
kubectl rollout status deployment/sample-httpbin -n sample-app
kubectl get pods -n sample-app -o wide
kubectl get ingress -n sample-app
curl -H 'Host: httpbin.localtest.me' http://<ingress-ip>/
```

권장 저장:

```bash
kubectl rollout status deployment/sample-httpbin -n sample-app | tee artifacts/evidence/phase5-sample-httpbin-rollout.txt
kubectl get ingress -n sample-app | tee artifacts/evidence/phase5-sample-httpbin-ingress.txt
curl -H 'Host: httpbin.localtest.me' http://<ingress-ip>/ | tee artifacts/evidence/phase5-sample-httpbin-curl.txt
```

완료 기준:

- `sample-httpbin` 2개 replica가 `Ready`
- ingress 경로가 응답 `200`
- app pod가 `topology.k3s.io/role=app` 노드에 스케줄됨
