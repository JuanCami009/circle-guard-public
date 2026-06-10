#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# In Jenkins (Docker), LOCALSTACK_HOST=host.docker.internal; locally defaults to localhost
LS_HOST="${LOCALSTACK_HOST:-localhost}"
LS_URL="http://${LS_HOST}:4566"

# Run AWS CLI via Docker — no local installation required
awscli() {
  docker run --rm \
    -e AWS_ACCESS_KEY_ID=test \
    -e AWS_SECRET_ACCESS_KEY=test \
    -e AWS_DEFAULT_REGION=us-east-1 \
    amazon/aws-cli \
    --endpoint-url "${LS_URL}" "$@"
}

# Skip docker compose if LocalStack already healthy
if curl -sf "${LS_URL}/_localstack/health" 2>/dev/null | grep -qE '"s3": "(available|running)"'; then
  echo "==> LocalStack already running and healthy. Skipping startup."
else
  echo "==> Starting LocalStack..."
  docker compose -f "${SCRIPT_DIR}/localstack-compose.yml" up -d --no-recreate 2>/dev/null \
    || docker compose -f "${SCRIPT_DIR}/localstack-compose.yml" up -d

  echo "==> Waiting for LocalStack to be ready (up to 180s)..."
  ELAPSED=0
  until curl -sf "${LS_URL}/_localstack/health" 2>/dev/null | grep -qE '"s3": "(available|running)"'; do
    if [ "$ELAPSED" -ge 180 ]; then
      echo "ERROR: LocalStack did not become ready within 180 seconds." >&2
      exit 1
    fi
    sleep 3
    ELAPSED=$((ELAPSED + 3))
  done
  echo "==> LocalStack is ready."
fi

echo "==> Creating S3 bucket 'circleguard-tfstate'..."
awscli s3 mb s3://circleguard-tfstate 2>/dev/null || true

echo "==> Enabling versioning on 'circleguard-tfstate'..."
awscli s3api put-bucket-versioning \
  --bucket circleguard-tfstate \
  --versioning-configuration Status=Enabled

echo "==> Creating DynamoDB lock table 'circleguard-tflock'..."
awscli dynamodb create-table \
  --table-name circleguard-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || true

echo "==> Verifying resources..."
awscli s3 ls
awscli dynamodb list-tables

echo "Backend bootstrap complete."
