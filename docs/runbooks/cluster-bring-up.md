# Cluster Bring-up Runbook

- 문서 상태: Draft
- 작성일: 2026-04-06
- 목적: Phase 2 완료 증거부터 Phase 3 K3S bring-up까지의 실제 실행 순서를 고정한다.

## 1. Phase 2 증거 확보

CloudShell 또는 Terragrunt가 설치된 실행 환경에서 아래 순서로 수행한다.

1. `terragrunt/dev/inputs.hcl`를 실제 환경 값으로 채운다.
2. 필요 시 수동 생성한 SG ID를 `existing_*_security_group_id` 입력에 넣는다.
3. cache 경로를 `/tmp`로 설정한다.
4. `terragrunt plan`을 실행하고 결과를 파일로 남긴다.

```bash
mkdir -p /tmp/.terragrunt-cache /tmp/.terraform-plugin-cache
export TG_DOWNLOAD_DIR="/tmp/.terragrunt-cache"
export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugin-cache"

cd terragrunt/dev
terragrunt plan -no-color | tee ../../artifacts/evidence/terragrunt-plan.txt
```

동일 절차를 스크립트로 실행하려면:

```bash
bash scripts/cloudshell-plan.sh
```

## 2. Terraform 출력 확인

적용 이후 아래 출력이 다음 단계 handoff 계약이다.

- `bastion_public_ip`
- `bastion_private_ip`
- `k3s_server_private_ip`
- `k3s_server_endpoint`
- `k3s_node_names_by_role`
- `k3s_node_roles_by_name`

권장 저장:

```bash
terragrunt output -json | tee ../../artifacts/evidence/terragrunt-output.json
```

## 3. Bastion 경유 K3S bootstrap

1. bastion에 접속한다.
2. server 노드에서 `server-init.sh`를 실행한다.
3. worker 노드별로 `agent-init.sh`를 실행한다.
4. infra 전용 노드에는 권장 taint를 부여한다.

예시:

```bash
K3S_TOKEN='<shared-token>'

scp -P 22022 bootstrap/k3s/*.sh ubuntu@${BASTION_PUBLIC_IP}:~/

ssh -p 22022 ubuntu@${BASTION_PUBLIC_IP}

K3S_TOKEN="$K3S_TOKEN" \
K3S_NODE_NAME="server" \
K3S_NODE_LABELS="topology.k3s.io/role=server" \
~/server.sh "bash ~/server-init.sh"
```

agent 예시:

```bash
K3S_SERVER_HOST='<server-private-ip>' \
K3S_TOKEN="$K3S_TOKEN" \
K3S_NODE_NAME="metrics" \
K3S_NODE_LABELS="topology.k3s.io/role=metrics" \
K3S_NODE_TAINTS="dedicated=metrics:NoSchedule" \
~/metrics.sh "bash ~/agent-init.sh"
```

로컬에서 인자 계약만 맞춰 실행하려면:

```bash
K3S_SERVER_HOST='<server-private-ip>' \
K3S_TOKEN='<shared-token>' \
bash scripts/bootstrap-k3s-role.sh agent metrics 'topology.k3s.io/role=metrics' 'dedicated=metrics:NoSchedule'
```

## 4. Ready 검증

server 노드에서 아래 증거를 남긴다.

```bash
kubectl get nodes -o wide | tee ~/phase3-kubectl-get-nodes.txt
kubectl get nodes --show-labels | tee ~/phase3-kubectl-get-nodes-labels.txt
```

완료 기준:

- 전체 노드가 `Ready`
- `topology.k3s.io/role` 라벨이 역할별로 보임
- infra 전용 노드 taint가 적용됨

## 5. 후속 handoff

- 샘플 앱: `kubectl apply -k kubernetes/apps/sample-httpbin`
- observability: `kubectl apply -k kubernetes/platform/observability`
- langfuse: `kubectl apply -k kubernetes/platform/langfuse`

실행 증거 수집은 [`workload-rollout.md`](/Users/len/Desktop/project/k8s/docs/runbooks/workload-rollout.md)와
[`phase-evidence.md`](/Users/len/Desktop/project/k8s/docs/runbooks/phase-evidence.md)를 따른다.
