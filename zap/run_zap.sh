#!/bin/bash
# ============================================================
# Pruebas de Seguridad — OWASP ZAP Baseline (punto 5)
# Ejecuta un escaneo pasivo ZAP contra los 8 microservicios de
# CircleGuard desplegados en Kubernetes.
#
# Uso local (requiere servicios accesibles):
#   bash zap/run_zap.sh
#
# Variables de entorno:
#   ZAP_HOST       Host donde los NodePorts son accesibles (default: host.docker.internal)
#   ZAP_FAIL_ON    Nivel de alerta que aborta el script: High (default), Medium, Low
#   ZAP_TIMEOUT    Timeout en segundos por servicio (default: 120)
#
# Puertos NodePort de prod (Jenkinsfile.master):
#   notification  30082 | identity   30083 | dashboard  30084
#   file          30085 | form       30086 | gateway    30087
#   promotion     30088 | auth       30180
# ============================================================

set -euo pipefail

ZAP_HOST="${ZAP_HOST:-host.docker.internal}"
ZAP_FAIL_ON="${ZAP_FAIL_ON:-High}"
ZAP_TIMEOUT="${ZAP_TIMEOUT:-120}"
ZAP_IMAGE="ghcr.io/zaproxy/zaproxy:stable"
REPORTS_DIR="$(pwd)/zap/reports"
RULES_FILE="$(pwd)/zap/rules.tsv"

mkdir -p "$REPORTS_DIR"

# Mapa: nombre → puerto (defaults = prod; sobreescribir con ZAP_PORT_* para otros entornos)
declare -A SERVICES
SERVICES=(
    ["notification-service"]="${ZAP_PORT_NOTIFICATION:-30082}"
    ["identity-service"]="${ZAP_PORT_IDENTITY:-30083}"
    ["dashboard-service"]="${ZAP_PORT_DASHBOARD:-30084}"
    ["file-service"]="${ZAP_PORT_FILE:-30085}"
    ["form-service"]="${ZAP_PORT_FORM:-30086}"
    ["gateway-service"]="${ZAP_PORT_GATEWAY:-30087}"
    ["promotion-service"]="${ZAP_PORT_PROMOTION:-30088}"
    ["auth-service"]="${ZAP_PORT_AUTH:-30180}"
)

PASS=0
FAIL=0
SKIP=0
SCAN_RESULTS=()
SUITE_START=$(date +%s)

# Convierte nivel de alerta a flag válido de zap-baseline.
# ZAP -l acepta: PASS, IGNORE, INFO, WARN, FAIL (no Low/Medium/High).
# WARN es el nivel de display para alertas Medium+; exit code 2 indica alertas altas.
fail_level_to_zap_flag() {
    case "$1" in
        Low)    echo "-l INFO" ;;
        Medium) echo "-l WARN" ;;
        High)   echo "-l WARN" ;;
        *)      echo "-l WARN" ;;
    esac
}

ZAP_LEVEL_FLAG=$(fail_level_to_zap_flag "$ZAP_FAIL_ON")

echo "============================================================"
echo "OWASP ZAP Baseline Scan — CircleGuard"
echo "Host: $ZAP_HOST | Nivel de fallo: $ZAP_FAIL_ON | Timeout: ${ZAP_TIMEOUT}s"
echo "============================================================"

for svc in "${!SERVICES[@]}"; do
    port="${SERVICES[$svc]}"
    target_url="http://${ZAP_HOST}:${port}"
    report_html="${REPORTS_DIR}/zap-${svc}.html"
    report_json="${REPORTS_DIR}/zap-${svc}.json"

    echo ""
    echo ">>> Escaneando ${svc} en ${target_url} ..."

    # Verificar que el servicio responde antes de lanzar ZAP
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${target_url}/" || true)
    if [ "$code" = "000" ]; then
        echo "[SKIP] ${svc} — sin respuesta en ${target_url} (servicio no disponible)"
        SCAN_RESULTS+=("$(printf '%-40s' "$svc")  SKIP   (puerto ${port} no responde)")
        SKIP=$((SKIP+1))
        continue
    fi

    # No se usa -v porque en DinD (Docker socket passthrough) el daemon del host
    # no puede acceder a paths dentro del contenedor Jenkins.
    # Patrón: docker create → docker cp rules → docker start → docker cp reports → docker rm
    container_name="zap-scan-${svc}-$$"

    zap_args="zap-baseline.py -t ${target_url} ${ZAP_LEVEL_FLAG} -r zap-${svc}.html -J zap-${svc}.json -d"
    if [ -f "$RULES_FILE" ]; then
        zap_args="$zap_args -c /zap/wrk/rules.tsv"
    fi

    docker rm -f "${container_name}" 2>/dev/null || true
    # shellcheck disable=SC2086
    docker create --name "${container_name}" --network host ${ZAP_IMAGE} ${zap_args} >/dev/null

    if [ -f "$RULES_FILE" ]; then
        docker cp "$RULES_FILE" "${container_name}:/zap/wrk/rules.tsv" 2>/dev/null || true
    fi

    zap_exit=0
    t_start=$(date +%s)
    timeout "${ZAP_TIMEOUT}" docker start -a "${container_name}" || zap_exit=$?
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))

    # Extraer reportes del contenedor al workspace
    docker cp "${container_name}:/zap/wrk/zap-${svc}.html" "${REPORTS_DIR}/" 2>/dev/null || true
    docker cp "${container_name}:/zap/wrk/zap-${svc}.json" "${REPORTS_DIR}/" 2>/dev/null || true
    docker rm -f "${container_name}" 2>/dev/null || true

    # ZAP exit codes: 0 = sin alertas, 1 = advertencias, 2 = errores/alta
    if [ "$zap_exit" -eq 0 ]; then
        echo "[PASS] ${svc} — sin alertas ${ZAP_FAIL_ON} (${elapsed}s)"
        SCAN_RESULTS+=("$(printf '%-40s' "$svc")  PASS   (sin alertas, ${elapsed}s)")
        PASS=$((PASS+1))
    elif [ "$zap_exit" -eq 1 ]; then
        echo "[WARN] ${svc} — alertas por debajo de ${ZAP_FAIL_ON} (${elapsed}s)"
        SCAN_RESULTS+=("$(printf '%-40s' "$svc")  WARN   (alertas menores, ${elapsed}s)")
        PASS=$((PASS+1))
    else
        echo "[FAIL] ${svc} — alertas ${ZAP_FAIL_ON} encontradas (${elapsed}s) → ver ${report_html}"
        SCAN_RESULTS+=("$(printf '%-40s' "$svc")  FAIL   (alertas ${ZAP_FAIL_ON}, ${elapsed}s)")
        FAIL=$((FAIL+1))
    fi
done

SUITE_END=$(date +%s)
SUITE_ELAPSED=$(( SUITE_END - SUITE_START ))
OVERALL="PASS"
[ "$FAIL" -gt 0 ] && OVERALL="FAIL"

echo ""
echo "============================================================"
echo "Desglose por servicio:"
for result in "${SCAN_RESULTS[@]}"; do
    echo "  $result"
done
echo ""
echo "Resultados: ${PASS} pasaron | ${FAIL} fallaron | ${SKIP} omitidos"
echo "Duración  : ${SUITE_ELAPSED}s"
echo "Reportes  : ${REPORTS_DIR}/"
echo "Veredicto : $OVERALL"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "Se encontraron alertas de nivel ${ZAP_FAIL_ON} en ${FAIL} servicio(s)."
    echo "Revisar los reportes HTML en zap/reports/ y corregir o agregar reglas de exclusión en zap/rules.tsv."
    exit 1
fi
exit 0
