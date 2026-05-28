#!/usr/bin/env bash
set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "ERROR: environment argument required (dev|stage|prod)" >&2
  echo "Usage: $0 <env>" >&2
  exit 1
fi

ENV="$1"

case "$ENV" in
  dev)   TAG="dev" ;;
  stage) TAG="stage" ;;
  prod)  TAG="latest" ;;
  *)
    echo "ERROR: unknown environment '${ENV}'. Must be dev, stage, or prod." >&2
    exit 1
    ;;
esac

CLUSTER="circleguard-${ENV}"

SERVICES=(
  auth-service
  identity-service
  promotion-service
  notification-service
  form-service
  file-service
  gateway-service
  dashboard-service
)

echo "==> Loading images into kind cluster '${CLUSTER}' (tag: ${TAG})..."
for SVC in "${SERVICES[@]}"; do
  echo "    Loading circleguard/${SVC}:${TAG}"
  kind load docker-image "circleguard/${SVC}:${TAG}" --name "${CLUSTER}"
done

echo "==> All images loaded into cluster '${CLUSTER}'."
