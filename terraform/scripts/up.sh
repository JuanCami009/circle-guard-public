#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [ -z "${1:-}" ]; then
  echo "ERROR: environment argument required (dev|stage|prod)" >&2
  echo "Usage: $0 <env>" >&2
  exit 1
fi

ENV="$1"

case "$ENV" in
  dev|stage|prod) ;;
  *)
    echo "ERROR: unknown environment '${ENV}'. Must be dev, stage, or prod." >&2
    exit 1
    ;;
esac

ENV_DIR="${REPO_ROOT}/terraform/envs/${ENV}"
if [ ! -d "${ENV_DIR}" ]; then
  echo "ERROR: environment directory '${ENV_DIR}' does not exist." >&2
  exit 1
fi

# ── Step 1: Bootstrap backend (skip if LocalStack already running on :4566) ──
if curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1; then
  echo "==> LocalStack already running on :4566 — skipping bootstrap."
else
  echo "==> Bootstrapping backend..."
  bash "${SCRIPT_DIR}/bootstrap-backend.sh"
fi

# ── Step 2: Terraform init ────────────────────────────────────────────────────
echo "==> Running terraform init in ${ENV_DIR}..."
cd "${ENV_DIR}"
terraform init -input=false

# ── Step 3: Phase 1 — provision cluster only ─────────────────────────────────
echo "==> Phase 1: provisioning kind cluster..."
terraform apply -target=module.cluster -input=false -auto-approve

# ── Step 4: Load Docker images into the kind cluster ─────────────────────────
echo "==> Loading service images..."
bash "${SCRIPT_DIR}/load-images.sh" "${ENV}"

# ── Step 5: Phase 2 — provision everything else ──────────────────────────────
echo "==> Phase 2: provisioning remaining resources..."
cd "${ENV_DIR}"
terraform apply -input=false -auto-approve

# ── Step 6: Print NodePort URLs ──────────────────────────────────────────────
echo ""
echo "==> Deployment complete. Service URLs (NodePort):"
case "$ENV" in
  dev)
    echo "    Gateway:  http://localhost:31087"
    echo "    Auth:     http://localhost:31180"
    ;;
  stage)
    echo "    Gateway:  http://localhost:32087"
    echo "    Auth:     http://localhost:32180"
    ;;
  prod)
    echo "    Gateway:  http://localhost:30087"
    echo "    Auth:     http://localhost:30180"
    ;;
esac
