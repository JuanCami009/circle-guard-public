#!/bin/bash
# ============================================================
# Pruebas E2E — CircleGuard Dev Environment
# Ejecuta 5 flujos contra los NodePorts del namespace circleguard-dev.
#
# Variables de entorno:
#   E2E_HOST       Host donde los NodePorts son accesibles (default: host.docker.internal)
#   TEST_JWT        JWT válido para endpoints autenticados
#   TEST_ANON_ID    anonymousId del usuario de prueba
#   TEST_QR_TOKEN   QR token válido para validación de acceso
# ============================================================

HOST="${E2E_HOST:-host.docker.internal}"
TEST_JWT="${TEST_JWT:-}"
TEST_ANON_ID="${TEST_ANON_ID:-test-anon-id-placeholder}"
TEST_QR_TOKEN="${TEST_QR_TOKEN:-test-qr-token-placeholder}"

PASS=0
FAIL=0
SUITE_START=$(date +%s)

# Acumuladores por flujo (nombre|pass|fail)
FLOW_RESULTS=()
CURRENT_FLOW=""
FLOW_PASS=0
FLOW_FAIL=0
FLOW_START=0

start_flow() {
    CURRENT_FLOW="$1"
    FLOW_PASS=0
    FLOW_FAIL=0
    FLOW_START=$(date +%s)
}

end_flow() {
    local elapsed=$(( $(date +%s) - FLOW_START ))
    local verdict="PASS"
    [ "$FLOW_FAIL" -gt 0 ] && verdict="FAIL"
    FLOW_RESULTS+=("$(printf '%-45s' "$CURRENT_FLOW")  $verdict  (${FLOW_PASS}ok/${FLOW_FAIL}fail, ${elapsed}s)")
}

log_pass() {
    echo "[PASS] $1"
    PASS=$((PASS+1))
    FLOW_PASS=$((FLOW_PASS+1))
}

log_fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL+1))
    FLOW_FAIL=$((FLOW_FAIL+1))
}

check_http() {
    local label="$1" url="$2" expected="$3"
    local t_start t_end elapsed body
    t_start=$(date +%s)
    body=$(curl -s -w "\n%{http_code}" --max-time 10 "$url")
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))
    CODE=$(echo "$body" | tail -1)
    if echo "$expected" | grep -qw "$CODE"; then
        log_pass "$label (HTTP $CODE, ${elapsed}s)"
    else
        local snippet
        snippet=$(echo "$body" | head -1 | cut -c1-120)
        log_fail "$label — esperado [$expected] obtenido HTTP $CODE (${elapsed}s): $snippet"
    fi
}

# Verifica que el servicio está vivo: acepta cualquier respuesta HTTP (no 000 ni 5xx)
check_alive() {
    local label="$1" url="$2"
    local t_start t_end elapsed
    t_start=$(date +%s)
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url")
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))
    if [ "$CODE" = "000" ]; then
        log_fail "$label — sin respuesta (timeout o servicio caído, ${elapsed}s)"
    elif [ "${CODE:0:1}" = "5" ]; then
        log_fail "$label — error de servidor (HTTP $CODE, ${elapsed}s)"
    else
        log_pass "$label (HTTP $CODE — servicio vivo, ${elapsed}s)"
    fi
}

check_json_field() {
    local label="$1" url="$2" method="$3" body="$4" field="$5" expected_value="$6"
    local t_start t_end elapsed RESPONSE VALUE
    t_start=$(date +%s)
    if [ -n "$TEST_JWT" ]; then
        RESPONSE=$(curl -s --max-time 10 -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $TEST_JWT" \
            -d "$body")
    else
        RESPONSE=$(curl -s --max-time 10 -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$body")
    fi
    t_end=$(date +%s)
    elapsed=$(( t_end - t_start ))
    VALUE=$(echo "$RESPONSE" | grep -o "\"$field\":\"[^\"]*\"" | head -1 | sed "s/\"$field\":\"//;s/\"//")
    if [ "$VALUE" = "$expected_value" ]; then
        log_pass "$label (campo $field=$VALUE, ${elapsed}s)"
    elif echo "$RESPONSE" | grep -q "$expected_value"; then
        log_pass "$label (valor '$expected_value' encontrado, ${elapsed}s)"
    else
        local snippet
        snippet=$(echo "$RESPONSE" | cut -c1-200)
        log_fail "$label — '$field' esperado '$expected_value' (${elapsed}s): $snippet"
    fi
}

echo "============================================================"
echo "Iniciando pruebas E2E — Host: $HOST"
echo "============================================================"

# ------------------------------------------------------------------
# FLUJO 1: Health Check — los 6 servicios responden correctamente
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 1: Health Check de todos los servicios"
start_flow "FLUJO 1: Health Check (6 servicios)"
check_alive "notification-service" "http://$HOST:31082/api/v1/notifications"
check_alive "dashboard-service"    "http://$HOST:31084/api/v1/analytics/summary"
check_alive "file-service"         "http://$HOST:31085/api/v1/files"
check_alive "form-service"         "http://$HOST:31086/api/v1/questionnaires"
check_alive "gateway-service"      "http://$HOST:31087/api/v1/gate/health"
check_alive "promotion-service"    "http://$HOST:31088/api/v1/health/status/ping"
end_flow

# ------------------------------------------------------------------
# FLUJO 2: Listado de formularios activos (form-service)
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 2: Consulta de formularios activos (form-service)"
start_flow "FLUJO 2: Listado de formularios (form-service)"
check_http "form-service GET /api/v1/questionnaires" \
    "http://$HOST:31086/api/v1/questionnaires" \
    "200 401 403"
end_flow

# ------------------------------------------------------------------
# FLUJO 3: Resumen de estado en el dashboard (dashboard-service)
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 3: Consulta de analytics en dashboard-service"
start_flow "FLUJO 3: Analytics summary (dashboard-service)"
check_http "dashboard-service GET /api/v1/analytics/summary" \
    "http://$HOST:31084/api/v1/analytics/summary" \
    "200 401 403"
end_flow

# ------------------------------------------------------------------
# FLUJO 4: Validación de token QR en gateway-service
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 4: Validación de acceso con QR token (gateway-service)"
start_flow "FLUJO 4: Validación QR (gateway-service)"
if [ -n "$TEST_QR_TOKEN" ] && [ "$TEST_QR_TOKEN" != "test-qr-token-placeholder" ]; then
    check_json_field \
        "gateway-service POST /api/v1/gate/validate" \
        "http://$HOST:31087/api/v1/gate/validate" \
        "POST" \
        "{\"token\":\"$TEST_QR_TOKEN\"}" \
        "status" \
        "GREEN"
else
    log_fail "FLUJO 4 — TEST_QR_TOKEN no configurado (usar credencial Jenkins 'e2e-qr-token')"
fi
end_flow

# ------------------------------------------------------------------
# FLUJO 5: Estado de salud de usuario en promotion-service
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 5: Consulta de estado de salud (promotion-service)"
start_flow "FLUJO 5: Health status (promotion-service)"
check_http "promotion-service GET /api/v1/health/status/$TEST_ANON_ID" \
    "http://$HOST:31088/api/v1/health/status/$TEST_ANON_ID" \
    "200 401 403 404"
end_flow

# ------------------------------------------------------------------
# Resumen final
# ------------------------------------------------------------------
SUITE_END=$(date +%s)
SUITE_ELAPSED=$(( SUITE_END - SUITE_START ))
OVERALL="PASS"
[ "$FAIL" -gt 0 ] && OVERALL="FAIL"

echo ""
echo "============================================================"
echo "Desglose por flujo:"
for result in "${FLOW_RESULTS[@]}"; do
    echo "  $result"
done
echo ""
echo "Resultados : $PASS pasaron | $FAIL fallaron"
echo "Duración   : ${SUITE_ELAPSED}s"
echo "Veredicto  : $OVERALL"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
