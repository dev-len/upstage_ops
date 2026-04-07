# Cluster Bring-up Runbook

- 문서 상태: Draft
- 작성일: 2026-04-06
- 목적: Phase 2 완료 증거부터 Phase 3 K3S bring-up까지의 실제 실행 순서를 고정한다.

현재까지의 실제 실패 사례와 스크립트 선택 기준은 [current-status-and-script-guide.md](/Users/len/Desktop/project/k8s/docs/runbooks/current-status-and-script-guide.md)를 본다.

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

`k3s_bootstrap_token`이 설정된 새 인스턴스라면, 이 단계 대부분은 첫 부팅 `user_data`에서 자동 수행된다.
이 경우 사람은 bastion 접속 후 helper 경로와 `kubectl get nodes` 결과만 확인하면 된다.

CloudShell 표준 경로는 수동 단계보다 one-shot을 우선한다.

```bash
SSH_IDENTITY_FILE=~/.ssh/k3s-dev-key.pem bash scripts/cloudshell-bootstrap-all.sh
```

자동 bootstrap 운영 기준과 `-replace` 전략은 [k3s-auto-bootstrap.md](/Users/len/Desktop/project/k8s/docs/runbooks/k3s-auto-bootstrap.md)를 우선 기준으로 본다.

1. bastion에 접속한다.
2. `/opt/k3s-bootstrap` helper 경로를 확인한다.
3. server kubeconfig 기준으로 `kubectl get nodes`를 확인한다.
4. 필요하면 evidence 파일을 저장한다.

자동화 경로 확인:

```bash
ssh -p 22022 ubuntu@${BASTION_PUBLIC_IP}
ls -la /opt/k3s-bootstrap
```

전체 node 교체 적용은 아래 스크립트를 기본으로 사용한다.

```bash
bash scripts/cloudshell-replace-apply.sh
```

적용 후 최신 private IP 기반 bastion wrapper를 다시 만들려면:

```bash
bash scripts/sync-bastion-wrappers.sh
```

one-shot은 IP가 변할 수 있다는 전제를 두고 apply 이후 output/AWS 조회로 최신 IP를 다시 해석한다.

기존 인스턴스를 재사용 중이거나 `k3s_bootstrap_token` 없이 apply한 경우에만 아래 수동 절차를 fallback으로 사용한다.

### Fallback: 수동 SSH bootstrap

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
bash scripts/phase3-verify.sh
```

완료 기준:

- 전체 노드가 `Ready`
- `topology.k3s.io/role` 라벨이 역할별로 보임
- infra 전용 노드 taint가 적용됨
- worker 전체 `Ready`가 아니면 workload 단계로 가지 않음

## 5. 후속 handoff

- 샘플 앱: `kubectl apply -k kubernetes/apps/sample-httpbin`
- observability: `kubectl apply -k kubernetes/platform/observability`
- langfuse: `kubectl apply -k kubernetes/platform/langfuse`

실행 증거 수집은 [`workload-rollout.md`](/Users/len/Desktop/project/k8s/docs/runbooks/workload-rollout.md)와
[`phase-evidence.md`](/Users/len/Desktop/project/k8s/docs/runbooks/phase-evidence.md)를 따른다.
