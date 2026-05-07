"""
Pruebas de rendimiento y estrés — CircleGuard
Simula cuatro perfiles de usuario real del sistema.

Ejecución local:
    pip install locust
    locust -f locustfile.py --config locust.conf

Ejecución headless con Docker (desde raíz del proyecto):
    docker run --rm --network host \
      -v "$PWD/locust:/mnt/locust" \
      locustio/locust \
      -f /mnt/locust/locustfile.py \
      --config /mnt/locust/locust.conf

Variables de entorno disponibles:
    LOCUST_HOST        URL base del servicio objetivo
    LOCUST_JWT         JWT de prueba para endpoints autenticados
    LOCUST_ANON_ID     anonymousId del usuario de prueba
    LOCUST_QR_TOKEN    QR token para validación en portería
"""

import os
import uuid
from locust import HttpUser, task, between, events

# ── Configuración de credenciales de prueba ───────────────────────────────────
TEST_JWT     = os.getenv("LOCUST_JWT",      "")
TEST_ANON_ID = os.getenv("LOCUST_ANON_ID",  str(uuid.uuid4()))
TEST_QR_TOKEN = os.getenv("LOCUST_QR_TOKEN", "")

AUTH_HEADERS = {"Authorization": f"Bearer {TEST_JWT}"} if TEST_JWT else {}


def _check(resp, label: str) -> None:
    """Falla solo en 5xx o sin respuesta; los 4xx son errores de negocio esperados."""
    if resp.status_code >= 500:
        resp.failure(f"{label}: HTTP {resp.status_code}")
    else:
        resp.success()


# ── Perfil 1: Consulta de estado de salud (operación más frecuente) ───────────
class HealthStatusUser(HttpUser):
    """
    Simula usuarios (estudiantes/staff) consultando su estado de salud.
    Es la operación de mayor volumen: ocurre en cada acceso al campus.
    """
    host = os.getenv("LOCUST_HOST_PROMOTION", os.getenv("LOCUST_HOST", "http://host.docker.internal:31088"))
    wait_time = between(1, 3)
    weight = 5

    @task(5)
    def get_own_status(self):
        with self.client.get(
            f"/api/v1/health/status/{TEST_ANON_ID}",
            headers=AUTH_HEADERS,
            catch_response=True,
            name="/api/v1/health/status/[anonymousId]"
        ) as resp:
            _check(resp, "health-status")

    @task(1)
    def get_health_actuator(self):
        with self.client.get(
            "/actuator/health",
            catch_response=True,
            name="/actuator/health"
        ) as resp:
            if resp.status_code != 200:
                resp.failure(f"Health endpoint down: {resp.status_code}")


# ── Perfil 2: Envío de encuestas de síntomas (form-service) ───────────────────
class SurveySubmissionUser(HttpUser):
    """
    Simula usuarios completando el formulario diario de síntomas.
    Flujo de menor frecuencia pero de mayor impacto en el grafo.
    """
    host = os.getenv("LOCUST_HOST_FORM", os.getenv("LOCUST_HOST", "http://host.docker.internal:31086"))
    wait_time = between(3, 8)
    weight = 2

    @task(3)
    def submit_health_survey(self):
        payload = {
            "anonymousId": TEST_ANON_ID,
            "hasSymptoms": False,
            "temperature": 36.5,
            "symptoms": []
        }
        with self.client.post(
            "/api/v1/surveys",
            json=payload,
            headers=AUTH_HEADERS,
            catch_response=True,
            name="/api/v1/surveys [POST]"
        ) as resp:
            _check(resp, "survey-submit")

    @task(1)
    def list_questionnaires(self):
        with self.client.get(
            "/api/v1/questionnaires",
            headers=AUTH_HEADERS,
            catch_response=True,
            name="/api/v1/questionnaires [GET]"
        ) as resp:
            _check(resp, "questionnaires-list")


# ── Perfil 3: Validación de acceso en portería (gateway-service) ──────────────
class GatewayValidationUser(HttpUser):
    """
    Simula lectores de QR en cada punto de acceso del campus.
    Es el cuello de botella más critico: todos los ingresos pasan por aquí.
    """
    host = os.getenv("LOCUST_HOST_GATEWAY", os.getenv("LOCUST_HOST", "http://host.docker.internal:31087"))
    wait_time = between(0.5, 2)
    weight = 8

    @task(10)
    def validate_qr_token(self):
        token = TEST_QR_TOKEN if TEST_QR_TOKEN else "invalid-token-for-load-test"
        with self.client.post(
            "/api/v1/gate/validate",
            json={"token": token},
            catch_response=True,
            name="/api/v1/gate/validate [POST]"
        ) as resp:
            # 200 con valid:false (token inválido) es correcto bajo carga
            if resp.status_code >= 500:
                resp.failure(f"Gateway 5xx: {resp.status_code}")
            else:
                resp.success()


# ── Perfil 4: Consulta de analítica (dashboard-service) ───────────────────────
class DashboardAnalyticsUser(HttpUser):
    """
    Simula coordinadores de salud revisando el panel de analítica.
    Frecuencia baja, pero las consultas pueden ser costosas.
    """
    host = os.getenv("LOCUST_HOST_DASHBOARD", os.getenv("LOCUST_HOST", "http://host.docker.internal:31084"))
    wait_time = between(5, 15)
    weight = 1

    @task(2)
    def get_status_summary(self):
        with self.client.get(
            "/api/v1/analytics/summary",
            headers=AUTH_HEADERS,
            catch_response=True,
            name="/api/v1/analytics/summary [GET]"
        ) as resp:
            _check(resp, "analytics-summary")

    @task(1)
    def get_exposure_heatmap(self):
        with self.client.get(
            "/api/v1/analytics/heatmap",
            headers=AUTH_HEADERS,
            catch_response=True,
            name="/api/v1/analytics/heatmap [GET]"
        ) as resp:
            _check(resp, "analytics-heatmap")


# ── Listener: métricas al terminar ────────────────────────────────────────────
@events.quitting.add_listener
def on_quitting(environment, **kwargs):
    stats  = environment.runner.stats
    total  = stats.total

    # SLA: p95 < 500 ms y menos del 1% de errores 5xx
    p95    = total.get_response_time_percentile(0.95) or 0
    sla_ok = p95 < 500 and total.fail_ratio < 0.01

    print("\n========== RESUMEN DE RENDIMIENTO ==========")
    print(f"  Peticiones totales : {total.num_requests}")
    print(f"  Fallos (5xx)       : {total.num_failures}")
    print(f"  Tasa de errores    : {total.fail_ratio * 100:.1f}%")
    print(f"  RPS promedio       : {total.current_rps:.1f}")
    print(f"  Latencia p50       : {total.get_response_time_percentile(0.50):.0f} ms")
    print(f"  Latencia p95       : {p95:.0f} ms")
    print(f"  Latencia p99       : {total.get_response_time_percentile(0.99):.0f} ms")

    print("\n--- Desglose por endpoint (solo 5xx cuentan como fallo) ---")
    for (method, name), entry in sorted(stats.entries.items(), key=lambda x: x[0][1]):
        if entry.num_requests == 0:
            continue
        verdict = "OK    " if entry.num_failures == 0 else f"FALLO ({entry.num_failures}/{entry.num_requests})"
        ep50 = entry.get_response_time_percentile(0.50) or 0
        ep95 = entry.get_response_time_percentile(0.95) or 0
        print(f"  [{verdict}] {method:4} {name:<45} {entry.num_requests:5} req | p50={ep50:.0f}ms p95={ep95:.0f}ms")

    print(f"\n  Veredicto SLA (p95<500ms, <1% 5xx) : {'APROBADO' if sla_ok else 'REPROBADO'}")
    print("============================================\n")
