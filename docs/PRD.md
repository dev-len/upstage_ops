# PRD: LLM 서비스 운영 환경 초기 구축

- **문서 상태**: Draft
- **작성일**: 2026-04-02
- **프로젝트 유형**: Ops (인프라 운영 및 자동화)
- **주요 역할**: DevOps

### 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2026-04-02 | 0.1 | 초안 작성 | - |
| 2026-04-02 | 0.2 | 보안, 네트워크, 노드 역할, Phase DoD, 성공기준 정량화 보완 | - |

## 문제 정의

팀은 LLM 서비스를 개발하고 운영할 수 있는 실습용 인프라 환경이 필요하다.
현재는 AWS 학습용 계정 제약이 큰 환경에서, Terraform으로 인프라를 만들고 K3S 기반 멀티 노드 클러스터를 운영하며,
관측(메트릭, 로그, 트레이스)과 LLM 전용 관측까지 포함한 운영 기반을 갖추려 한다.

이 프로젝트의 핵심 문제는 다음과 같다.

- 제한된 AWS 권한과 Cloud Shell 실행 환경 안에서 재현 가능한 인프라 구성이 필요하다
- 낮은 리소스(`t3.medium`) 환경에서도 앱, 관측 스택, LLM 관측 스택을 분리 운영할 수 있어야 한다
- 팀이 Kubernetes 운영, observability, LLM observability를 함께 학습할 수 있어야 한다
- 향후 Next.js 또는 React + FastAPI 기반 서비스가 개발되면 바로 배포할 수 있는 운영 기반이 필요하다
- 애플리케이션이 개발되면 자동으로 build 및 deploy 가능한 전달 경로가 필요하다
- AI를 활용한 서비스 특성에 맞는 LLM 게이트웨이 계층도 검토할 필요가 있다

## 목표

- Terraform으로 AWS 인프라를 프로비저닝할 수 있는 구조를 정의한다
- K3S 멀티 노드 클러스터를 구축하여 역할별 워크로드 분리가 가능하도록 한다
- 프론트엔드와 백엔드 서비스가 개발되면 바로 배포할 수 있는 애플리케이션 런타임 환경을 준비한다
- 애플리케이션 변경이 자동 build 및 deploy로 이어지는 기본 배포 자동화 경로를 마련한다
- Grafana 기반으로 메트릭, 로그, 트레이스를 통합 조회할 수 있도록 한다
- Langfuse를 셀프 호스팅하여 LLM 호출 추적, 프롬프트 관리, 비용 추적이 가능하도록 한다
- Envoy AI Gateway를 검토하여 AI 트래픽 제어 계층을 실습 가능한 구조를 마련한다
- 팀이 반복 실행 가능한 운영 환경과 학습 가능한 구조를 함께 확보하도록 한다

## 비목표

- 프로덕션급 고가용성(HA) 보장
- 완전한 비용 최적화
- 멀티 리전 또는 멀티 클러스터 운영
- 복잡한 멀티 스테이지 배포 파이프라인 구축
- 다수 환경(dev/stage/prod) 동시 운영
- 특정 애플리케이션 서비스 기능 구현

## 사용자 및 이해관계자

- **직접 사용자**
  - DevOps 담당자: 인프라 프로비저닝, 클러스터 운영, 관측 스택 및 배포 자동화 구축
  - 팀 개발자: 클러스터에 앱을 배포하고 관측 데이터를 확인
- **간접 이해관계자**
  - 프로젝트 팀원: 서비스 스택 선택 및 배포 방향 결정
  - AWS 학습 계정 관리자: 사용 가능한 리소스와 권한 범위 제약

## 용어 정의

| 용어 | 설명 |
|------|------|
| K3S | 경량 Kubernetes 배포판. 단일 바이너리로 동작하며 리소스 소비가 적다 |
| OTel | OpenTelemetry. 원격 측정 데이터 수집을 위한 업계 표준 프레임워크 |
| LGTM 스택 | Loki(로그) + Grafana(시각화) + Tempo(트레이스) + Mimir/Prometheus(메트릭) |
| Langfuse | 오픈소스 LLM 관측 플랫폼. 호출 추적, 프롬프트 관리, 비용 추적 지원 |
| Envoy AI Gateway | Envoy 기반 AI/LLM 요청 제어 및 관리 게이트웨이 |
| EBS | Elastic Block Store. AWS의 블록 스토리지 서비스 |
| Cloud Shell | AWS에서 제공하는 브라우저 기반 CLI 환경 |

## 환경 제약

### AWS 학습용 계정 제약

| 항목 | 상태 |
|------|------|
| AWS 리전 | `us-east-1` |
| IAM 사용자/역할 생성 | 제한됨 |
| 외부 Access Key 생성 | 제한됨 |
| EC2 인스턴스 크기 | `medium`까지 허용 |
| EC2 인스턴스 수 | 제한 없음 |
| 운영 OS | Ubuntu 22.04 LTS |
| Terraform 실행 위치 | AWS Cloud Shell |

### Cloud Shell 제약

- 세션 종료 후 `$HOME` 외 디렉터리는 초기화된다
- Terraform 바이너리, provider cache, state 관리 방식에 대한 별도 전략이 필요하다
- 원격 backend 사용 가능 여부는 IAM 제한 확인이 선행되어야 한다

## 확정된 결정

아래 항목은 ADR로 이미 확정되었으며, 이 문서에서는 실행 전제로 취급한다.

- 텔레메트리 수집은 하이브리드 방식 사용
  - 참조: [`ADR-001`](/Users/len/Desktop/project/k8s/docs/adr/001-adopt-hybrid-telemetry-collection.md)
- LLM 관측 도구는 Langfuse 사용
  - 참조: [`ADR-002`](/Users/len/Desktop/project/k8s/docs/adr/002-select-langfuse-for-llm-observability.md)
- K3S는 멀티 노드 역할 분리 구조 채택
  - 참조: [`ADR-003`](/Users/len/Desktop/project/k8s/docs/adr/003-adopt-k3s-multi-node-topology.md)
- 시각화 플랫폼은 Grafana로 통일
  - 참조: [`ADR-004`](/Users/len/Desktop/project/k8s/docs/adr/004-standardize-on-grafana-for-visualization.md)

## 요구사항

### 기능 요구사항

- AWS 인프라를 Cloud Shell에서 Terraform으로 프로비저닝할 수 있어야 한다
- K3S 서버 1대와 에이전트 N대로 멀티 노드 클러스터를 구성할 수 있어야 한다
- 앱 워크로드, 관측 스택, DB, LLM observability를 역할별로 분리 배치할 수 있어야 한다
- 프론트엔드와 백엔드 애플리케이션을 컨테이너 기준으로 배포할 수 있어야 한다
- 서비스 스택이 Next.js 또는 React + FastAPI 중 어느 쪽이든 배포 가능한 구조여야 한다
- 소스 변경 이후 자동 build와 자동 deploy가 가능한 기본 파이프라인이 있어야 한다
- AI 서비스 요청 경로에서 LLM gateway 계층을 붙일 수 있는 구조여야 한다
- 메트릭, 로그, 트레이스를 수집하고 Grafana에서 통합 조회할 수 있어야 한다
- Langfuse를 통해 LLM 호출 추적 및 프롬프트 관리가 가능해야 한다
- 프론트엔드와 백엔드 모두 계측 가능한 구조여야 한다

### 비기능 요구사항

- 제한된 리소스 환경에서도 단계적으로 확장 가능한 구조여야 한다
- 반복 실행과 재구성이 가능해야 한다
- 학습 목적상 각 도구의 역할과 경계가 드러나는 구조여야 한다
- 팀 협업 시 결정 사항과 미결정 사항이 분리되어 문서화되어야 한다
- 빌드/배포 자동화는 팀이 운영 가능한 수준의 단순한 구조여야 한다

### 보안 요구사항

- EC2 인스턴스 SSH 접근은 Key Pair 기반으로 제한한다
- K3S API Server 접근은 kubeconfig 기반으로 제어한다
- Grafana, Langfuse 등 웹 UI는 기본 인증(ID/PW)을 설정한다
- Kubernetes Secret을 통해 민감 정보(DB 비밀번호, API 키 등)를 관리한다
- Security Group으로 노드 간 통신 포트와 외부 접근 포트를 최소화한다
- SSH 접근용 Bastion 구성 여부는 Phase 2에서 결정한다

## 범위

### 이번 단계 범위

- Terraform 기반 AWS 인프라 프로비저닝 구조 정의
- K3S 멀티 노드 클러스터 구축
- 프론트엔드 및 백엔드 애플리케이션 배포를 위한 클러스터 런타임 환경 준비
- 자동 build 및 deploy를 위한 기본 파이프라인 구조 정의
- Prometheus, Loki, Tempo, Grafana 기반 observability 스택 구축
- OpenTelemetry Collector 기반 로그/트레이스 수집 구조 구축
- Langfuse 저장소 스택(PostgreSQL, ClickHouse, Redis) 구조 정의 및 배포 준비
- Envoy AI Gateway 도입 가능성 및 배치 위치 검토

### 후속 단계 범위

- 다단계 승인형 파이프라인
- 고급 GitOps 운영 정책
- 커스텀 Grafana 대시보드 고도화
- 서비스별 세부 계측 확장
- Envoy AI Gateway 운영 정책 고도화

## 제안 솔루션 요약

### 인프라 및 클러스터

- Terraform으로 VPC, Subnet, Security Group, EC2, EBS를 관리한다
- Cloud Shell 환경에서 Terraform을 실행한다
- K3S는 서버 1대 + 에이전트 N대 구조로 시작한다
- 최소 구성은 서버 1 + 에이전트 2~3이며, 서비스 스택 확정 후 노드 수를 조정한다

#### 노드 역할 할당 (ADR-003 기준)

| 노드 역할 | 수량 | 워크로드 | 비고 |
|-----------|------|----------|------|
| Server | 1대 | K3S 컨트롤 플레인 (etcd, API Server, Scheduler) | 필수 |
| Agent: App | 1대~ | 애플리케이션 서비스 (Next.js / React + FastAPI) | 서비스 스택 확정 후 조정 |
| Agent: Obs | 1대 | 관측 스택 (Prometheus, Grafana, Loki, Tempo, OTel) | 리소스 격리 목적 |
| Agent: DB | 1대 | PostgreSQL (App + Langfuse metadata), ClickHouse, Redis | 초기에는 공용 저장소 노드로 운영 |
| Agent: LLM-Obs | 1대 | Langfuse | 메모리 512MB+ 예상 |

> 최종 노드 수는 서비스 스택 확정 후 조정한다. 최소 서버 1 + 에이전트 2~3에서 시작.

### 네트워크 구조

- 기존 AWS 기본 VPC와 서브넷(`us-east-1a` ~ `us-east-1f`, `172.31.x.x/20`)을 사용한다
- 노드 간 통신은 Private IP 기반이며, Security Group으로 필요 포트만 허용한다
- 외부 접근은 K3S 기본 Traefik Ingress를 통해 처리한다
- SSL 인증서 및 도메인 연결은 Phase 1 확인 결과에 따라 결정한다

### 애플리케이션 배포 및 자동화

- 프론트엔드와 백엔드는 컨테이너 이미지 기준으로 배포한다
- 기본 배포 자동화는 소스 변경 -> 이미지 build -> 서버 전송 또는 내부 저장소 반영 -> 클러스터 반영 흐름을 목표로 한다
- GitHub Actions는 사용 가능하되, 컨테이너 이미지를 public registry에 업로드하는 방식은 사용하지 않는다
- 초기 배포 전략은 이미지 direct transfer(`scp` + node import)로 검토한다
- 목표 배포 전략은 self-hosted private registry를 통해 멀티 노드 배포를 단순화하는 것이다

### AI Gateway

- Envoy AI Gateway는 일반 ingress 대체재가 아니라 AI/LLM 요청 제어 계층으로 검토한다
- 기존 K3S ingress는 일반 웹 트래픽 진입점으로 유지한다
- Envoy AI Gateway는 AI 서비스 요청 경로에 별도 배치하는 방향을 후보안으로 기록한다
- 이번 단계에서는 도입하지 않고, 후속 검토 항목으로만 유지한다
- 학습 목표상 Envoy 계열 게이트웨이 운영 경험을 쌓는 대상에 포함한다

### Observability

- Metrics: Prometheus가 직접 pull 기반 scrape 수행
- Logs: OpenTelemetry Collector가 수집 후 Loki로 전송
- Traces: OpenTelemetry Collector가 수집 후 Tempo로 전송
- Visualization: Grafana 단일 UI 사용

### LLM Observability

- Langfuse를 셀프 호스팅한다
- Langfuse 저장소 스택은 PostgreSQL, ClickHouse, Redis를 기준으로 한다
- 초기안으로 애플리케이션 DB와 Langfuse metadata는 동일 PostgreSQL 인스턴스를 공유할 수 있다
- 단, 앱 DB와 Langfuse metadata는 데이터베이스/사용자/권한을 분리하여 운영한다
- 인프라 트레이스와 LLM 호출 추적은 함께 운영하되, 도구 역할은 분리한다

## 단계별 실행 계획

### Phase 1. 착수 전 확인

- IAM 제한 범위를 확인한다
- S3 backend 및 DynamoDB lock 사용 가능 여부를 확인한다
- EC2 동시 실행 vCPU limit를 확인한다 (4~5대 동시 운영 가능 여부)
- 도메인 및 DNS 사용 가능 여부를 확인한다
- 서비스 스택 후보(Next.js, React + FastAPI) 중 우선 대상을 정한다

> **완료 기준**: 위 5개 항목에 대한 확인 결과가 문서화되고, 블로커 여부가 판단된 상태

### Phase 2. 인프라 기반 준비

- Cloud Shell에서 Terraform을 반복 실행할 수 있는 작업 구조를 정의한다
- 상태 파일 저장 전략을 결정한다 (S3 불가 시 대안: local state + Git 관리)
- VPC, 네트워크, EC2, EBS 기반 리소스 구성을 설계한다
- SSH 접근 방식(직접 접근 vs Bastion) 결정

> **완료 기준**: `terraform plan`이 Cloud Shell에서 성공적으로 실행되고, 리소스 설계 문서가 작성된 상태

### Phase 3. K3S 클러스터 구축

- 서버 노드와 에이전트 노드 구성 방식을 정한다
- 역할별 노드 분리 기준을 정리한다 (Taint/Toleration, Node Affinity)
- 설치 자동화 방식(`user_data` 또는 `cloud-init`)을 정한다

> **완료 기준**: `kubectl get nodes`에서 전체 노드가 `Ready` 상태이고, 역할별 label/taint가 적용된 상태

### Phase 4. Observability 스택 구축

- Prometheus, Loki, Tempo, Grafana 배포 구조를 정의한다 (Helm chart vs raw manifest 결정 포함)
- OTel Collector 배포 방식을 정한다 (DaemonSet vs Deployment)
- Grafana에서 세 신호를 통합 조회할 수 있도록 한다
- 데이터 보존 정책(Retention)을 정한다

> **완료 기준**: Grafana에서 메트릭(Prometheus), 로그(Loki), 트레이스(Tempo) 데이터가 각각 조회되는 상태
>
> ⚡ Phase 5와 병렬 진행 가능

### Phase 5. 애플리케이션 배포 기반 구성

- 프론트엔드 및 백엔드 배포 매니페스트 구조를 정한다
- 이미지 build 후 direct transfer 및 node import 경로를 정한다
- GitHub Actions 기반 자동 배포 구조를 정한다
- self-hosted private registry 도입 시점을 후속 전략으로 정리한다
- 샘플 애플리케이션(예: nginx 또는 httpbin)을 배포하여 파이프라인을 검증한다

> **완료 기준**: 샘플 앱이 클러스터에 배포되어 외부에서 접근 가능하고, 코드 push 후 자동 빌드/배포 흐름이 1회 이상 성공한 상태
>
> ⚡ Phase 4와 병렬 진행 가능

### Phase 6. AI Gateway 검토

- Envoy AI Gateway 관련 요구사항과 검토 포인트를 문서화한다
- 일반 ingress와 AI gateway의 역할 경계를 후속 과제로 정리한다

> **완료 기준**: Envoy AI Gateway 검토 문서(ADR 또는 별도 문서)가 작성된 상태

### Phase 7. 앱 계측 및 LLM Observability

- 서비스 스택별 OTel 계측 방식을 선택한다
- 애플리케이션용 PostgreSQL과 Langfuse 저장소 스택(PostgreSQL, ClickHouse, Redis) 배치 전략을 확정한다
- 공용 PostgreSQL 인스턴스를 사용할 경우 DB/사용자/권한 분리 방식을 정한다
- 앱 계측, 인프라 트레이스, LLM trace 간 관계를 정리한다

> **완료 기준**: Langfuse UI에서 LLM 호출 trace가 조회되고, Grafana에서 앱 트레이스가 확인되는 상태

### Phase 8. 후속 고도화

- 배포 정책 고도화 여부를 검토한다
- GitOps 운영 범위 확장을 별도 의사결정으로 분리한다

> **완료 기준**: 후속 고도화 대상 목록 및 우선순위가 정리된 상태

## 성공 기준

| # | 기준 | 검증 방법 |
|---|------|-----------|
| 1 | Terraform으로 AWS 인프라를 반복 적용 가능한 형태로 관리할 수 있다 | `terraform plan`/`apply` 반복 실행 시 핵심 리소스 구성이 일관되게 유지됨 |
| 2 | K3S 멀티 노드 클러스터가 정상 동작한다 | `kubectl get nodes` 전체 노드 `Ready` 상태 |
| 3 | 샘플 애플리케이션을 클러스터에 배포할 수 있다 | nginx 또는 httpbin 컨테이너가 정상 응답 |
| 4 | 서비스 개발 후 정해진 경로로 배포 가능하다 | 배포 매니페스트 적용 시 추가 수작업 불필요 |
| 5 | 코드 변경 이후 자동 build 및 deploy가 동작한다 | Git push 후 새 이미지가 클러스터에 반영 확인 |
| 6 | Grafana에서 metrics, logs, traces를 조회할 수 있다 | Grafana Data Source 3개 연결 및 데이터 조회 확인 |
| 7 | Langfuse에서 LLM 호출 trace를 확인할 수 있다 | 테스트 LLM 호출 후 Langfuse UI에서 trace 조회 |
| 8 | 문서만 읽고 팀원이 다음 작업 순서를 이해할 수 있다 | 팀원 워크스루 세션으로 검증 |

## 오픈 이슈 및 결정 게이트

### 착수 전 확정 필요

- IAM 제한 범위 정확히 파악
- Cloud Shell에서 Terraform state 영속성 보장 방법 결정
- 도메인 보유 여부 및 DNS 설정 방식 확인

### 설계 중 확정 필요

- 팀 서비스 스택 확정 (`Next.js` 또는 `React + FastAPI`)
- 노드 수 최종 확정
- 자동 build/deploy 구현 방식 확정 (`GitHub Actions + direct transfer`를 초기안으로 검토)
  - GitHub Actions self-hosted runner 필요 여부 검토 (VPC 내 EC2 접근 문제)
  - 멀티 노드 환경에서의 이미지 배포 워크플로우 구체화
  - 롤백 전략 정의
- self-hosted private registry 도입 시점 결정
- 애플리케이션 PostgreSQL과 Langfuse metadata를 같은 PostgreSQL 인스턴스로 공유할지 최종 확정
- Langfuse 저장소 스택(PostgreSQL, ClickHouse, Redis) 영속 볼륨 전략 결정
- 공용 PostgreSQL 사용 시 리소스 경쟁과 장애 전파 허용 범위 정의
- Prometheus, Loki, Tempo 데이터 보존 정책(Retention) 결정
- Stateful 워크로드(Prometheus TSDB, Loki chunks) 영속 볼륨 전략 결정
- Grafana 대시보드 범위 결정
- Grafana 대시보드 JSON Git 관리 방식 결정

### 비용 추정 (참고)

> 아래는 개략적인 예측이며, 실제 비용은 가동 시간과 사용량에 따라 달라진다.

| 항목 | 단가(예상) | 수량 | 월 예상 비용 |
|------|-----------|------|-------------|
| EC2 `t3.medium` | ~$0.0416/hr | 4~5대 | ~$120~150 |
| EBS gp3 (20GB/노드) | ~$0.08/GB/월 | 80~100GB | ~$6~8 |
| 데이터 전송 | 제한적 사용 예상 | - | ~$5 이하 |
| **합계** | | | **~$130~165/월** |

### 후속 검토 항목

- Envoy AI Gateway 도입 범위 및 배치 방식 검토
- 일반 ingress와 AI gateway의 역할 분리 방식 정리

### 이미 확정된 항목

- LLM 관측 도구: Langfuse
- K3S 클러스터 방향: 멀티 노드 역할 분리
- 텔레메트리 수집 방식: 하이브리드
- 시각화 플랫폼: Grafana

## 목표 구조 초안

아래 구조는 구현 시작 시점의 목표 구조이며, 실제 디렉터리 구성은 Phase 진행에 따라 조정될 수 있다.

```text
k8s/
├── docs/
│   ├── PRD.md
│   ├── adr/
│   └── prompts/
├── terraform/
│   ├── environments/
│   │   └── dev/
│   └── modules/
├── k3s/
├── manifests/
│   ├── gateway/
│   ├── observability/
│   ├── langfuse/
│   └── apps/
└── scripts/
```

## 참고 문서

- [`docs/prompts/260402.md`](/Users/len/Desktop/project/k8s/docs/prompts/260402.md)
- [`docs/adr/001-adopt-hybrid-telemetry-collection.md`](/Users/len/Desktop/project/k8s/docs/adr/001-adopt-hybrid-telemetry-collection.md)
- [`docs/adr/002-select-langfuse-for-llm-observability.md`](/Users/len/Desktop/project/k8s/docs/adr/002-select-langfuse-for-llm-observability.md)
- [`docs/adr/003-adopt-k3s-multi-node-topology.md`](/Users/len/Desktop/project/k8s/docs/adr/003-adopt-k3s-multi-node-topology.md)
- [`docs/adr/004-standardize-on-grafana-for-visualization.md`](/Users/len/Desktop/project/k8s/docs/adr/004-standardize-on-grafana-for-visualization.md)
