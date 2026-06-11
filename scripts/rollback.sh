#!/usr/bin/env bash
# rollback.sh  - Revierte uno o todos los microservicios de CircleGuard
# al deployment anterior usando 'kubectl rollout undo'.
#
# Uso:
#   bash scripts/rollback.sh <servicio|all> [--to-revision N]
#
#   servicio       Nombre del deployment a revertir (ej: auth-service)
#   all            Revierte los 8 microservicios en secuencia
#   --to-revision  Opcional: revierte a la revisión K8s específica N
#
# Requisito: kubectl configurado y apuntando al clúster con namespace 'circleguard'.
# Nota: las imágenes usan imagePullPolicy: Never (clúster local).
#       Si la imagen anterior fue sobreescrita, usa el Plan B de rollback
#       (checkout del tag vX.Y.Z + rebuild de imágenes + redeploy).
set -euo pipefail

NAMESPACE="circleguard"

SERVICES=(
  "auth-service"
  "dashboard-service"
  "file-service"
  "form-service"
  "gateway-service"
  "identity-service"
  "notification-service"
  "promotion-service"
)

# ─── Parsing de argumentos ───────────────────────────────────────────────────

if [ $# -lt 1 ]; then
    echo "Error: se requiere el nombre del servicio o 'all'." >&2
    echo "Uso: bash scripts/rollback.sh <servicio|all> [--to-revision N]" >&2
    exit 1
fi

TARGET="$1"
shift

TO_REVISION=""
while [ $# -gt 0 ]; do
    case "$1" in
        --to-revision)
            TO_REVISION="$2"
            shift 2
            ;;
        *)
            echo "Argumento desconocido: $1" >&2
            exit 1
            ;;
    esac
done

# ─── Validaciones previas ─────────────────────────────────────────────────────

if ! command -v kubectl &>/dev/null; then
    echo "Error: kubectl no está instalado o no está en PATH." >&2
    exit 1
fi

if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "Error: namespace '$NAMESPACE' no existe en el clúster actual." >&2
    exit 1
fi

# ─── Función de rollback para un servicio ─────────────────────────────────────

rollback_service() {
    local svc="$1"
    echo "" >&2
    echo "──────────────────────────────────────────────" >&2
    echo "rollback: procesando deployment/$svc" >&2

    if ! kubectl get deployment "$svc" -n "$NAMESPACE" &>/dev/null; then
        echo "  WARN: deployment/$svc no existe en namespace $NAMESPACE  - omitiendo." >&2
        return 0
    fi

    echo "  Historial de revisiones:" >&2
    kubectl rollout history deployment/"$svc" -n "$NAMESPACE" >&2 || true

    if [ -n "$TO_REVISION" ]; then
        echo "  Revirtiendo a revisión $TO_REVISION..." >&2
        kubectl rollout undo deployment/"$svc" -n "$NAMESPACE" --to-revision="$TO_REVISION"
    else
        echo "  Revirtiendo a revisión anterior..." >&2
        kubectl rollout undo deployment/"$svc" -n "$NAMESPACE"
    fi

    echo "  Esperando que el rollback complete..." >&2
    kubectl rollout status deployment/"$svc" -n "$NAMESPACE" --timeout=120s >&2

    echo "  OK: rollback completado para $svc." >&2
}

# ─── Ejecución ────────────────────────────────────────────────────────────────

if [ "$TARGET" = "all" ]; then
    echo "rollback: revirtiendo los ${#SERVICES[@]} microservicios en namespace $NAMESPACE..." >&2
    for svc in "${SERVICES[@]}"; do
        rollback_service "$svc"
    done
else
    rollback_service "$TARGET"
fi

# ─── Estado post-rollback ─────────────────────────────────────────────────────

echo "" >&2
echo "──────────────────────────────────────────────" >&2
echo "Estado de pods en namespace $NAMESPACE tras el rollback:" >&2
kubectl get pods -n "$NAMESPACE" >&2

echo "" >&2
echo "rollback: proceso finalizado." >&2
echo "" >&2
echo "NOTA: si los deployments están en 0 réplicas (el pipeline los escala a 0 en post.always)," >&2
echo "      re-escala con:" >&2
echo "      kubectl scale deployment --all -n $NAMESPACE --replicas=1" >&2
echo "" >&2
echo "NOTA: para rollback por versión de código (Plan B), usa:" >&2
echo "      git checkout -b rollback/vX.Y.Z vX.Y.Z" >&2
echo "      # reconstruir imágenes + recargar en el nodo + kubectl rollout restart" >&2
