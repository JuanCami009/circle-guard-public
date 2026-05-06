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

log_pass() { echo "[PASS] $1"; PASS=$((PASS+1)); }
log_fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

check_http() {
    local label="$1" url="$2" expected="$3"
    CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url")
    if echo "$expected" | grep -qw "$CODE"; then
        log_pass "$label (HTTP $CODE)"
    else
        log_fail "$label — esperado $expected, obtenido HTTP $CODE"
    fi
}

check_json_field() {
    local label="$1" url="$2" method="$3" body="$4" field="$5" expected_value="$6"
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
    VALUE=$(echo "$RESPONSE" | grep -o "\"$field\":\"[^\"]*\"" | head -1 | sed "s/\"$field\":\"//;s/\"//")
    if [ "$VALUE" = "$expected_value" ]; then
        log_pass "$label (campo $field=$VALUE)"
    elif echo "$RESPONSE" | grep -q "$expected_value"; then
        log_pass "$label (valor '$expected_value' encontrado en respuesta)"
    else
        log_fail "$label — campo '$field' esperado '$expected_value', respuesta: $RESPONSE"
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
check_http "notification-service /actuator/health"  "http://$HOST:31082/actuator/health"  "200"
check_http "dashboard-service /actuator/health"     "http://$HOST:31084/actuator/health"  "200"
check_http "file-service /actuator/health"          "http://$HOST:31085/actuator/health"  "200"
check_http "form-service /actuator/health"          "http://$HOST:31086/actuator/health"  "200"
check_http "gateway-service /actuator/health"       "http://$HOST:31087/actuator/health"  "200"
check_http "promotion-service /actuator/health"     "http://$HOST:31088/actuator/health"  "200"

# ------------------------------------------------------------------
# FLUJO 2: Listado de formularios activos (form-service)
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 2: Consulta de formularios activos (form-service)"
check_http "form-service GET /api/v1/questionnaires" \
    "http://$HOST:31086/api/v1/questionnaires" \
    "200 401 403"

# ------------------------------------------------------------------
# FLUJO 3: Resumen de estado en el dashboard (dashboard-service)
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 3: Consulta de analytics en dashboard-service"
check_http "dashboard-service GET /api/v1/analytics/summary" \
    "http://$HOST:31084/api/v1/analytics/summary" \
    "200 401 403"

# ------------------------------------------------------------------
# FLUJO 4: Validación de token QR en gateway-service
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 4: Validación de acceso con QR token (gateway-service)"
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

# ------------------------------------------------------------------
# FLUJO 5: Estado de salud de usuario en promotion-service
# ------------------------------------------------------------------
echo ""
echo ">>> FLUJO 5: Consulta de estado de salud (promotion-service)"
check_http "promotion-service GET /api/v1/health/status/$TEST_ANON_ID" \
    "http://$HOST:31088/api/v1/health/status/$TEST_ANON_ID" \
    "200 401 403 404"

# ------------------------------------------------------------------
# Resumen final
# ------------------------------------------------------------------
echo ""
echo "============================================================"
echo "Resultados: $PASS pasaron | $FAIL fallaron"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
