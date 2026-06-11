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
CONTROL_PLANE="${CLUSTER}-control-plane"

# Verify cluster node is running before attempting kind load
if ! docker inspect --format "{{.State.Running}}" "${CONTROL_PLANE}" 2>/dev/null | grep -q "true"; then
  echo "ERROR: kind cluster node '${CONTROL_PLANE}' is not running." >&2
  echo "       Run: terraform taint module.cluster.null_resource.cluster && terraform apply -target=module.cluster" >&2
  exit 1
fi

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
