# k8s Infra Workspace

이 저장소는 AWS 학습용 계정 제약 안에서 K3S 7노드 기준선을 단계적으로 만드는 인프라 작업공간이다.

현재 기준선은 다음까지 포함한다.

- `server + worker-shared` Security Group bootstrap
- bastion SSH entrypoint
- 7노드 EC2 baseline
- stateful 역할용 storage baseline
- K3S bootstrap 스크립트
- observability / Langfuse 배치 values
- Kubernetes workload layer
- Terragrunt dev entrypoint
- IaC validation / pipeline 문서

## 시작점

- Terragrunt 실행 가이드: [README.md](/Users/len/Desktop/project/k8s/terragrunt/README.md)
- Terraform 구조 설명: [README.md](/Users/len/Desktop/project/k8s/terraform/README.md)
- 작업 기준 문서: [README.md](/Users/len/Desktop/project/k8s/docs/tasks/README.md)
- 검증 기준: [validation-baseline.md](/Users/len/Desktop/project/k8s/docs/tasks/validation-baseline.md)
- IaC 실행 경로: [iac-pipeline.md](/Users/len/Desktop/project/k8s/docs/tasks/iac-pipeline.md)
- Cluster bring-up: [cluster-bring-up.md](/Users/len/Desktop/project/k8s/docs/runbooks/cluster-bring-up.md)
- K3S auto bootstrap: [k3s-auto-bootstrap.md](/Users/len/Desktop/project/k8s/docs/runbooks/k3s-auto-bootstrap.md)
- Current status and script guide: [current-status-and-script-guide.md](/Users/len/Desktop/project/k8s/docs/runbooks/current-status-and-script-guide.md)
- Workload rollout: [workload-rollout.md](/Users/len/Desktop/project/k8s/docs/runbooks/workload-rollout.md)
- Kubernetes manifests: [README.md](/Users/len/Desktop/project/k8s/kubernetes/README.md)
- AI Gateway 검토: [007-document-envoy-ai-gateway-evaluation-boundary.md](/Users/len/Desktop/project/k8s/docs/adr/007-document-envoy-ai-gateway-evaluation-boundary.md)
- Evidence artifacts: [README.md](/Users/len/Desktop/project/k8s/artifacts/evidence/README.md)

## Script Guide

루트 기준으로 가장 자주 쓰는 스크립트는 아래 4개다.

- `bash scripts/cloudshell-plan.sh`
  - CloudShell에서 `terragrunt plan`과 output 저장
- `bash scripts/cloudshell-replace-apply.sh`
  - bastion + 전체 node를 replace apply
- `bash scripts/phase3-verify.sh`
  - server 기준 Phase 3 검증
- `bash scripts/capture-phase-evidence.sh`
  - 현재 환경 기준 evidence / blocked 상태 저장

권장 실행 순서:

1. `git pull`
2. `terragrunt/dev/inputs.hcl` 확인
3. `bash scripts/cloudshell-plan.sh`
4. `bash scripts/cloudshell-replace-apply.sh`
5. bastion / server 확인
6. `bash scripts/phase3-verify.sh`

실패 이력, 현재 상태, 각 스크립트의 상세 설명은 [current-status-and-script-guide.md](/Users/len/Desktop/project/k8s/docs/runbooks/current-status-and-script-guide.md)를 본다.

## 실행 가이드

### 1. 입력 준비

1. `terragrunt/dev/inputs.hcl.example`를 `terragrunt/dev/inputs.hcl`로 복사한다.
2. 실제 값을 채운다.
   - `vpc_id`
   - `admin_cidr`
   - `subnet_ids_by_az`
   - `ami_id`
   - `key_name`
3. 필요하면 baseline 입력도 조정한다.
  - `primary_az`
  - `instance_type`
  - `associate_public_ip_address`
  - `enable_bastion`
  - `bootstrap_bastion_helpers`
  - `k3s_bootstrap_token`
  - `k3s_server_extra_args`
  - `k3s_agent_extra_args_by_role`
  - `bastion_instance_type`
  - `bastion_associate_public_ip_address`
  - `enable_storage`
   - `root_volume_size_gb`
   - `root_volume_type`
   - `db_root_volume_size_gb`, `llm_obs_root_volume_size_gb`, `clickhouse_root_volume_size_gb`
   - `db_*`, `llm_obs_*`, `clickhouse_*`
   - `node_definitions`

### 2. 로컬 검토

로컬에서는 구조와 문서 정합성을 먼저 본다.

- `terraform fmt -check -recursive`
- `terragrunt hclfmt --check`
- `terragrunt validate`

현재 환경에 `terraform` 또는 `terragrunt`가 없으면 실패가 아니라 `blocked`로 기록한다.

### 3. CloudShell 실행

실제 AWS 실행은 CloudShell 기준으로 잡는다.

1. 필요한 바이너리와 cache 위치를 준비한다.
   ```bash
   mkdir -p /tmp/.terragrunt-cache
   mkdir -p /tmp/.terraform-plugin-cache

   export TG_DOWNLOAD_DIR="/tmp/.terragrunt-cache"
   export TF_PLUGIN_CACHE_DIR="/tmp/.terraform-plugin-cache"
   ```
2. 학습 계정에서 SG bootstrap 생성이 막히면, server SG와 worker-shared SG를 먼저 수동으로 만든다.
   ```bash
   SERVER_SG_ID=$(aws ec2 create-security-group \
     --group-name k3s-dev-server-sg \
     --description "Bootstrap SG for K3S server" \
     --vpc-id vpc-xxxxxxxxxxxxxxxxx \
     --query 'GroupId' \
     --output text)

   WORKER_SG_ID=$(aws ec2 create-security-group \
     --group-name k3s-dev-worker-shared-sg \
     --description "Bootstrap SG for shared K3S workers" \
     --vpc-id vpc-xxxxxxxxxxxxxxxxx \
     --query 'GroupId' \
     --output text)
   ```
3. 두 SG에 필요한 inbound rule만 추가한다.
   ```bash
   aws ec2 authorize-security-group-ingress --group-id "$SERVER_SG_ID" --ip-permissions \
   "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=203.0.113.10/32,Description=\"SSH from admin\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$WORKER_SG_ID" --ip-permissions \
   "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=203.0.113.10/32,Description=\"SSH from admin\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$SERVER_SG_ID" --ip-permissions \
   "IpProtocol=tcp,FromPort=6443,ToPort=6443,IpRanges=[{CidrIp=203.0.113.10/32,Description=\"K3S API from admin\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$SERVER_SG_ID" --ip-permissions \
   "IpProtocol=tcp,FromPort=6443,ToPort=6443,UserIdGroupPairs=[{GroupId=$WORKER_SG_ID,Description=\"K3S API from shared worker nodes\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$SERVER_SG_ID" --ip-permissions \
   "IpProtocol=udp,FromPort=8472,ToPort=8472,UserIdGroupPairs=[{GroupId=$SERVER_SG_ID,Description=\"Flannel VXLAN from server nodes\"},{GroupId=$WORKER_SG_ID,Description=\"Flannel VXLAN from shared worker nodes\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$WORKER_SG_ID" --ip-permissions \
   "IpProtocol=udp,FromPort=8472,ToPort=8472,UserIdGroupPairs=[{GroupId=$SERVER_SG_ID,Description=\"Flannel VXLAN from server nodes\"},{GroupId=$WORKER_SG_ID,Description=\"Flannel VXLAN from shared worker nodes\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$SERVER_SG_ID" --ip-permissions \
   "IpProtocol=tcp,FromPort=10250,ToPort=10250,UserIdGroupPairs=[{GroupId=$SERVER_SG_ID,Description=\"Kubelet from server nodes\"},{GroupId=$WORKER_SG_ID,Description=\"Kubelet from shared worker nodes\"}]"

   aws ec2 authorize-security-group-ingress --group-id "$WORKER_SG_ID" --ip-permissions \
   "IpProtocol=tcp,FromPort=10250,ToPort=10250,UserIdGroupPairs=[{GroupId=$SERVER_SG_ID,Description=\"Kubelet from server nodes\"},{GroupId=$WORKER_SG_ID,Description=\"Kubelet from shared worker nodes\"}]"
   ```
4. `terragrunt/dev/inputs.hcl`에 기존 SG ID를 넣는다.
   ```hcl
    existing_server_security_group_id        = "sg-xxxxxxxxxxxxxxxxx"
    existing_worker_shared_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
    existing_bastion_security_group_id       = "sg-xxxxxxxxxxxxxxxxx"
    manage_existing_bastion_ssh_ingress_rules = false
    associate_public_ip_address              = false
    enable_bastion                           = true
    enable_storage                           = false

    db_root_volume_size_gb         = 40
   llm_obs_root_volume_size_gb    = 40
   clickhouse_root_volume_size_gb = 100
   ```
5. `terragrunt/dev`에서 `terragrunt plan`을 실행한다.
6. 결과를 검토한다.
7. 수동 승인 후 `terragrunt apply`를 실행한다.

자동 bootstrap을 쓰려면 추가로 아래를 설정한다.

```hcl
bootstrap_bastion_helpers = true
k3s_bootstrap_token       = "replace-me-with-a-shared-token"
```

이 설정이 있으면:

- bastion은 첫 부팅에서 `/opt/k3s-bootstrap` 아래 helper를 자동 설치한다
- server/worker node는 첫 부팅에서 K3S를 자동 설치한다

주의:

- 이미 떠 있는 인스턴스는 `user_data`를 다시 실행하지 않는다
- 이미 생성된 인스턴스에 이 자동화를 반영하려면 `-replace` 또는 재생성이 필요하다
- 실제 적용은 `bash scripts/cloudshell-replace-apply.sh`를 기본으로 사용한다

주의:

- 장시간 실행은 `tmux` 사용
- CloudShell 용량 문제를 피하기 위해 Terragrunt/Terraform cache는 `/tmp` 아래를 우선 사용한다
- `TERRAGRUNT_DOWNLOAD`는 deprecated 경고가 있으므로 `TG_DOWNLOAD_DIR`를 사용한다
- remote backend 가능 여부는 IAM 제약 확인 후 결정
- 기본 VPC와 기존 서브넷은 입력값으로만 사용한다
- 현재 학습 계정에서는 outbound 규칙 삭제가 불가하므로, bootstrap SG는 기본 outbound를 그대로 둔다
- 현재 학습 계정에서는 `ec2:CreateVolume`도 불가하므로, 별도 EBS 대신 stateful 노드의 root volume 확장 경로를 사용한다
- bastion을 제외한 private fleet는 public IP 없이 운영하는 것을 기본으로 둔다
- bastion 외부 진입 포트만 `22022`로 바꾸고, private 노드 SSH는 `22`로 유지할 수 있다
- 기존 SG에 이미 `bastion -> server/worker : 22/tcp` 규칙이 있으면 `manage_existing_bastion_ssh_ingress_rules = false`로 두어 duplicate rule 에러를 피한다

### 4. K3S bootstrap

기본 경로는 first-boot 자동 bootstrap이다.

- 기준 문서: [k3s-auto-bootstrap.md](/Users/len/Desktop/project/k8s/docs/runbooks/k3s-auto-bootstrap.md)
- 실행/검증 순서: [cluster-bring-up.md](/Users/len/Desktop/project/k8s/docs/runbooks/cluster-bring-up.md)

Terraform 적용 후 수동 K3S bootstrap은 fallback으로만 사용한다.

- bootstrap 자산: [README.md](/Users/len/Desktop/project/k8s/bootstrap/k3s/README.md)
- bastion helper 자산: [README.md](/Users/len/Desktop/project/k8s/bootstrap/bastion/README.md)
- server script: [server-init.sh](/Users/len/Desktop/project/k8s/bootstrap/k3s/server-init.sh)
- agent script: [agent-init.sh](/Users/len/Desktop/project/k8s/bootstrap/k3s/agent-init.sh)

`k3s_bootstrap_token`을 설정한 경우에는 위 스크립트가 EC2 `user_data` 경로로 자동 실행된다.
수동 bootstrap은 기존 인스턴스를 재사용하거나 자동화 없이 점진 확인할 때만 사용한다.

Terraform 출력 중 아래가 직접 handoff 된다.

- `bastion_public_ip`
- `bastion_private_ip`
- `k3s_server_private_ip`
- `k3s_server_public_ip`
- `k3s_server_endpoint`
- `k3s_node_roles_by_name`
- `k3s_node_names_by_role`

표준 접속 경로는 `local/CloudShell -> bastion -> private nodes`다.
private node 접속은 고정 IP 대신 EC2 `Name` 태그 조회 기반 helper script를 bastion에서 실행하는 것을 기본으로 둔다.

### 5. Workload 배치

K3S bootstrap 이후 observability / Langfuse 배치는 별도 values를 기준으로 한다.

- observability: [README.md](/Users/len/Desktop/project/k8s/deployments/observability/README.md)
- langfuse: [README.md](/Users/len/Desktop/project/k8s/deployments/langfuse/README.md)
- kubernetes workload layer: [README.md](/Users/len/Desktop/project/k8s/kubernetes/README.md)

선언형 배포 진입점은 아래 순서를 기본으로 한다.

- `kubectl apply -k kubernetes/platform/observability`
- `kubectl apply -k kubernetes/platform/langfuse`
- `kubectl apply -k kubernetes/apps/sample-httpbin`

실제 배포 순서와 증거 수집은 [workload-rollout.md](/Users/len/Desktop/project/k8s/docs/runbooks/workload-rollout.md)를 따른다.

## 현재 제약

- 기본 VPC와 기존 서브넷을 재사용한다.
- 초기 SG 모델은 `server + worker-shared`다.
- `80/443` 공개와 역할별 SG 세분화는 아직 후속 작업이다.
- 실제 `terraform/terragrunt/helm/kubectl` 검증은 실행 환경 준비 여부에 따라 `blocked`가 될 수 있다.
