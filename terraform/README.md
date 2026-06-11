# CircleGuard — Terraform IaC

Local Kubernetes (kind) + LocalStack infrastructure for CircleGuard microservices.

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Docker | 24+ | Docker Compose v2+ included |
| [kind](https://kind.sigs.k8s.io/) | 0.23+ | Local Kubernetes clusters |
| Terraform | 1.9.x | Use [tfenv](https://github.com/tfutils/tfenv) and `.terraform-version` |
| AWS CLI | v2 | Used as `aws --endpoint-url` against LocalStack |
| kubectl | 1.29+ | Cluster introspection |
| jq | any | JSON parsing in health checks |

Install Terraform 1.9.8 quickly with tfenv:
```bash
tfenv install   # reads terraform/.terraform-version automatically
tfenv use 1.9.8
```

---

## Quick Start

### 1. Boot LocalStack

```bash
docker compose -f terraform/scripts/localstack-compose.yml up -d
```

LocalStack exposes S3, DynamoDB, SecretsManager, IAM, and STS on `http://localhost:4566`.

### 2. Bootstrap Terraform backend

```bash
bash terraform/scripts/bootstrap-backend.sh
```

This creates:
- S3 bucket `circleguard-tfstate` (versioned) — remote state storage
- DynamoDB table `circleguard-tflock` — state locking

Both are idempotent; safe to run multiple times.

### 3. Build service images

First package all Spring Boot JARs:
```bash
./gradlew bootJar -x test
```

Then build a Docker image for each service (example for `auth-service`):
```bash
docker build -t circleguard/auth-service:dev services/circleguard-auth-service/
```

Repeat for all 8 services:
`auth-service`, `identity-service`, `promotion-service`, `notification-service`,
`form-service`, `file-service`, `gateway-service`, `dashboard-service`.

### 4. Provision the dev environment (two-phase)

```bash
cd terraform/envs/dev

# Init providers and backend
terraform init

# Phase 1 — create the kind cluster first
terraform apply -target=module.cluster -auto-approve

# Load Docker images into the cluster
bash ../../scripts/load-images.sh dev

# Phase 2 — provision everything else (namespaces, services, infra)
terraform apply -auto-approve
```

### 5. Or use the one-shot orchestrator

```bash
bash terraform/scripts/up.sh dev
```

`up.sh` runs all four phases above automatically. Accepts `dev`, `stage`, or `prod`.

---

## Verify

```bash
# Check pods
kubectl get pods -A

# Check kind cluster
kubectl cluster-info --context kind-circleguard-dev

# Check LocalStack S3 bucket
aws --endpoint-url http://localhost:4566 s3 ls

# Check DynamoDB lock table
aws --endpoint-url http://localhost:4566 dynamodb list-tables
```

Set dummy credentials if needed:
```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
```

---

## Teardown

```bash
bash terraform/scripts/teardown.sh
```

This destroys all Terraform-managed resources, deletes all three kind clusters,
and stops LocalStack (with volume cleanup).

---

## Environment URLs (NodePort)

| Env | Gateway | Auth |
|---|---|---|
| dev | http://localhost:31087 | http://localhost:31180 |
| stage | http://localhost:32087 | http://localhost:32180 |
| prod | http://localhost:30087 | http://localhost:30180 |

---

## Directory Layout

```
terraform/
├── .terraform-version        # Pinned Terraform version (1.9.8)
├── README.md                 # This file
├── modules/
│   ├── kind-cluster/         # kind cluster + kubeconfig
│   ├── aws-s3-uploads/       # LocalStack S3 bucket for file-service
│   ├── aws-secrets/          # LocalStack SecretsManager secrets
│   ├── k8s-namespaces/       # Kubernetes namespace per service
│   ├── k8s-config/           # ConfigMaps and Secrets
│   ├── k8s-postgres/         # PostgreSQL StatefulSet
│   ├── k8s-neo4j/            # Neo4j StatefulSet
│   ├── k8s-kafka/            # Kafka + Zookeeper
│   ├── k8s-redis/            # Redis Deployment
│   ├── k8s-openldap/         # OpenLDAP Deployment
│   ├── k8s-mailhog/          # MailHog Deployment
│   └── k8s-microservice/     # Generic microservice Deployment + Service
├── envs/
│   ├── dev/                  # Dev environment root module
│   ├── stage/                # Stage environment root module
│   └── prod/                 # Prod environment root module
└── scripts/
    ├── localstack-compose.yml
    ├── bootstrap-backend.sh
    ├── load-images.sh
    ├── up.sh
    └── teardown.sh
```
