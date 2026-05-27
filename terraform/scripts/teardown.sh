#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENVS_DIR="${SCRIPT_DIR}/../envs"

# ── Step 1: Terraform destroy for each initialized environment ────────────────
if [ -d "${ENVS_DIR}" ]; then
  for ENV_DIR in "${ENVS_DIR}"/*/; do
    if [ -d "${ENV_DIR}/.terraform" ]; then
      ENV_NAME="$(basename "${ENV_DIR}")"
      echo "==> Destroying Terraform resources in '${ENV_NAME}'..."
      (cd "${ENV_DIR}" && terraform destroy -auto-approve) || \
        echo "    WARNING: terraform destroy failed for '${ENV_NAME}' — continuing."
    fi
  done
else
  echo "==> No envs/ directory found — skipping Terraform destroy."
fi

# ── Step 2: Delete kind clusters ─────────────────────────────────────────────
echo "==> Deleting kind cluster 'circleguard-dev'..."
kind delete cluster --name circleguard-dev || true

echo "==> Deleting kind cluster 'circleguard-stage'..."
kind delete cluster --name circleguard-stage || true

echo "==> Deleting kind cluster 'circleguard-prod'..."
kind delete cluster --name circleguard-prod || true

# ── Step 3: Stop LocalStack ───────────────────────────────────────────────────
echo "==> Stopping LocalStack..."
docker compose -f "${SCRIPT_DIR}/localstack-compose.yml" down -v

echo "Teardown complete."
