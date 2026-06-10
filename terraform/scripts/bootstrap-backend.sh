#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

# Skip docker compose if LocalStack already healthy
if curl -sf http://localhost:4566/_localstack/health 2>/dev/null | grep -q '"s3": "available"'; then
  echo "==> LocalStack already running and healthy. Skipping startup."
else
  echo "==> Starting LocalStack..."
  docker compose -f "${SCRIPT_DIR}/localstack-compose.yml" up -d --no-recreate 2>/dev/null \
    || docker compose -f "${SCRIPT_DIR}/localstack-compose.yml" up -d

  echo "==> Waiting for LocalStack to be ready (up to 180s)..."
  ELAPSED=0
  until curl -sf http://localhost:4566/_localstack/health | grep -q '"s3": "available"'; do
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
aws --endpoint-url http://localhost:4566 s3 mb s3://circleguard-tfstate 2>/dev/null || true

echo "==> Enabling versioning on 'circleguard-tfstate'..."
aws --endpoint-url http://localhost:4566 s3api put-bucket-versioning \
  --bucket circleguard-tfstate \
  --versioning-configuration Status=Enabled

echo "==> Creating DynamoDB lock table 'circleguard-tflock'..."
aws --endpoint-url http://localhost:4566 dynamodb create-table \
  --table-name circleguard-tflock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST 2>/dev/null || true

echo "==> Verifying resources..."
aws --endpoint-url http://localhost:4566 s3 ls
aws --endpoint-url http://localhost:4566 dynamodb list-tables

echo "Backend bootstrap complete."
