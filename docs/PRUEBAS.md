# Análisis de Pruebas — CircleGuard (Punto 5)

## Resumen ejecutivo

CircleGuard implementa una **pirámide de testing completa** con 5 niveles de prueba automatizadas, integradas en el pipeline Jenkins de CI/CD.

| Tipo | Herramienta | Archivos | Estado CI |
|---|---|---|---|
| Unitarias (backend) | JUnit 5 + Mockito | 49 archivos, 8 servicios | ✅ Unit Tests stage |
| Integración (backend) | Spring Boot Test + Testcontainers | 10 archivos, 8 servicios | ✅ Integration Tests stage |
| Unitarias (mobile) | Jest + RTL | 4 archivos | ✅ Mobile Tests stage |
| E2E | Bash + curl | 7 flujos, 8 servicios | ✅ E2E Tests stage (master) |
| Rendimiento | Locust | 6 perfiles de usuario | ✅ Performance Tests stage (master) |
| Seguridad | OWASP ZAP | 8 servicios | ✅ Security Tests stage (master) |

---

## Pirámide de testing

```
          /\
         /  \
        / E2E \          ← 7 flujos (run_e2e.sh)
       /--------\
      / Rendim. /\       ← Locust: 6 perfiles, 50 users, 60s
     /----------\  \
    / Seguridad  \  \    ← OWASP ZAP: 8 servicios
   /--------------\  \
  / Integración    \  \  ← 10 tests (H2 + Testcontainers Neo4j)
 /------------------\  \
/ Unit (49 archivos) \__/ ← base: 8 servicios Java + 4 archivos mobile
```

---

## 1. Pruebas Unitarias (backend)

### Ubicación
`services/circleguard-<service>/src/test/java/com/circleguard/<service>/`

### Por servicio

| Servicio | Tests | Clases clave |
|---|---|---|
| auth-service | 6 | `JwtTokenServiceTest`, `QrTokenServiceTest`, `LoginControllerTest`, `IdentityClientResilienceTest` |
| identity-service | 3 | `IdentityVaultControllerTest`, `IdentityEncryptionConverterTest` |
| promotion-service | 7 | `HealthStatusServiceTest`, `StatusLifecycleTest`, `SurveyListenerTest`, `FloorServiceTest` |
| notification-service | 9 | `NotificationDispatcherTest`, `NotificationRetryTest`, `PushServiceToggleTest`, etc. |
| form-service | 4 | `HealthSurveyControllerTest`, `QuestionnaireControllerTest`, `SymptomMapperTest` |
| file-service | 2 | `FileUploadControllerTest`, **`FileStorageServiceTest`** (nuevo) |
| gateway-service | 3 | `GateControllerTest`, `QrValidationServiceTest`, `QrValidationCacheTest` |
| dashboard-service | 3 | `AnalyticsControllerTest`, **`KAnonymityFilterTest`** (nuevo), **`AnalyticsServiceTest`** (nuevo) |

### Ejecución local
```bash
# Todos los servicios
./gradlew test

# Un servicio específico
./gradlew :services:circleguard-promotion-service:test

# Con reporte JaCoCo
./gradlew test jacocoTestReport
# → HTML: services/<svc>/build/reports/jacoco/test/html/index.html
```

---

## 2. Pruebas de Integración (backend)

### Estrategia
- **H2 in-memory** para JPA (auth, identity, form): ligero, sin Docker.
- **Testcontainers Neo4j** para grafo de contacto (promotion-service): contenedor real Neo4j `5.12`.
- **`@SpringBootTest` + MockMvc** con colaboradores externas mockeados (gateway, dashboard, file): contexto completo de Spring sin red real.

### Por servicio

| Servicio | Test | Infra |
|---|---|---|
| auth-service | `AuthUserRepositoryIntegrationTest` | H2 / `@DataJpaTest` |
| identity-service | `IdentityVaultServiceIntegrationTest`, `IdentityMappingRepositoryTest` | H2 / `@DataJpaTest` |
| promotion-service | `AdministrativeCorrectionTest`, `HealthStatusReevaluationTest`, `SurveyListenerIntegrationTest` | Testcontainers Neo4j |
| promotion-service | `PromotionPerformanceTest` | Testcontainers Neo4j (10k nodos, SLA < 1000ms) |
| form-service | `QuestionnaireJpaIntegrationTest` | H2 / `@DataJpaTest` |
| gateway-service | `GatewayValidationIntegrationTest` | `@SpringBootTest` + Redis mockeado |
| notification-service | `ExposureNotificationIntegrationTest` | `@SpringBootTest` + Kafka mockeado |
| dashboard-service | **`AnalyticsControllerIntegrationTest`** (nuevo) | `@SpringBootTest` + PromotionClient mockeado |
| file-service | **`FileUploadIntegrationTest`** (nuevo) | `@SpringBootTest` + filesystem real |

### Ejecución local
```bash
# Solo integration
./gradlew :services:circleguard-gateway-service:test \
    --tests "com.circleguard.gateway.integration.*"

# promotion con Testcontainers (requiere Docker)
./gradlew :services:circleguard-promotion-service:test \
    --tests "com.circleguard.promotion.integration.*"
```

> **Nota CI**: Los tests con Testcontainers Neo4j están deshabilitados en macOS CI (Docker Desktop limita el acceso al socket). En Linux CI corren correctamente vía `TESTCONTAINERS_RYUK_DISABLED=true`.

---

## 3. Pruebas Unitarias (mobile)

### Ubicación
`mobile/hooks/`, `mobile/components/__tests__/`, `mobile/context/__tests__/`, `mobile/utils/__tests__/`

| Archivo | Qué cubre |
|---|---|
| `hooks/useQrToken.test.ts` | Token init, timer decrement, rotación en 0 |
| `components/__tests__/DynamicForm.test.tsx` | Render preguntas, actualización respuesta texto |
| `context/__tests__/AuthContext.test.tsx` | Load desde storage, enroll, logout, error fuera de Provider |
| `utils/__tests__/storage.test.ts` | SecureStore (native) y localStorage (web) |

### Cobertura medida
- `collectCoverageFrom`: hooks, context, utils, components
- Formatos: `lcov`, `text`, `cobertura` (compatible con Jenkins Coverage Plugin)

### Ejecución local
```bash
cd mobile
npm test              # interactivo
npm run test:ci       # headless con coverage + JUnit XML
# → coverage/lcov-report/index.html
# → junit.xml (para Jenkins)
```

---

## 4. Pruebas E2E (end-to-end)

### Script
`e2e/run_e2e.sh` — 7 flujos HTTP contra los NodePorts de Kubernetes.

| Flujo | Servicio | Validación |
|---|---|---|
| 1 | Todos (8) | Health check: respuesta non-5xx, non-000 |
| 2 | form-service | `GET /questionnaires` → 200/401/403 |
| 3 | dashboard-service | `GET /analytics/summary` → 200/401/403 |
| 4 | gateway-service | `POST /gate/validate` con QR token real → `status: GREEN` |
| 5 | promotion-service | `GET /health/status/{id}` → 200/401/404 |
| 6 | auth-service | `GET /users/permissions/NOTIFY_PRIORITY_ALERTS` → 200/401/403 |
| 7 | identity-service | `POST /identities/visitor` → 200/401/403 |

### Variables de entorno
```bash
E2E_HOST=host.docker.internal
TEST_JWT=<jwt-valido>
TEST_ANON_ID=<anon-uuid>
TEST_QR_TOKEN=<qr-token-valido>   # opcional, flujo 4 se omite si no está
```

### Ejecución local
```bash
bash e2e/run_e2e.sh
```

---

## 5. Pruebas de Rendimiento y Estrés (Locust)

### Configuración
`locust/locustfile.py` + `locust/locust.conf`

| Parámetro | Valor |
|---|---|
| Usuarios concurrentes | 50 |
| Spawn rate | 5 usuarios/s |
| Duración | 60s |
| Modo | Headless (CI) |

### 6 perfiles de usuario simulados

| Perfil | Servicio | Peso | Descripción |
|---|---|---|---|
| `HealthStatusUser` | promotion | 5 | Consulta estado de salud — operación más frecuente |
| `SurveySubmissionUser` | form | 2 | Envío de encuesta diaria de síntomas |
| `GatewayValidationUser` | gateway | 8 | Validación QR en portería — cuello de botella crítico |
| `DashboardAnalyticsUser` | dashboard | 1 | Coordinadores revisando analytics |
| `AuthServiceUser` | auth | 3 | Consulta permisos + handoff de visitantes |
| `IdentityServiceUser` | identity | 2 | Registro y mapeo de identidades |

### SLA definido
- **p95 < 500ms** en todos los endpoints
- **< 1% de fallos 5xx**

### Interpretación del reporte
El reporte HTML (`locust/locust-report-master.html`) muestra:
- Distribución de latencia (p50, p95, p99) por endpoint
- Tasa de fallos y RPS promedio
- Veredicto SLA (APROBADO / REPROBADO) al final del log

### Ejecución local (Docker)
```bash
docker build -t circleguard-locust -f locust/Dockerfile locust/
docker run --rm --network host \
  -e LOCUST_HOST_GATEWAY="http://host.docker.internal:31087" \
  circleguard-locust \
  -f /mnt/locust/locustfile.py \
  --config /mnt/locust/locust.conf
```

---

## 6. Pruebas de Seguridad (OWASP ZAP)

### Script
`zap/run_zap.sh` — ZAP Baseline (pasivo) contra los 8 servicios.

| Parámetro | Valor |
|---|---|
| Imagen ZAP | `ghcr.io/zaproxy/zaproxy:stable` |
| Modo | Baseline (passive scan) — sin ataques activos |
| Nivel de fallo | `High` (bloqueante en prod) |
| Timeout por servicio | 120s |

### Reglas personalizadas
`zap/rules.tsv` — suprime falsos positivos de API REST:
- CSP headers (no aplica a APIs sin UI)
- Cookie flags (API usa JWT Bearer, no cookies)
- CORS abierto (intencional para app móvil)

### Interpretación de resultados

| Exit code | Significado | Acción |
|---|---|---|
| 0 | Sin alertas del nivel configurado | ✅ Ninguna |
| 1 | Alertas menores (< High) | ⚠️ Revisar reporte HTML, sin bloqueo |
| 2 | Alertas High o Critical | ❌ Corregir código o justificar en `rules.tsv` |

Los reportes HTML se archivan en `zap/reports/zap-<servicio>.html`.

### Ejecución local
```bash
# Requiere servicios accesibles en host.docker.internal:300xx
bash zap/run_zap.sh

# Solo un servicio (debug)
ZAP_HOST=localhost ZAP_TIMEOUT=60 bash zap/run_zap.sh
```

---

## Cobertura de código

### Backend (JaCoCo)
Configurado en `build.gradle.kts` — cada `Test` task genera automáticamente el reporte XML+HTML.

```bash
# Generar reportes de todos los servicios
./gradlew jacocoTestReport

# Ver reporte HTML de un servicio
open services/circleguard-dashboard-service/build/reports/jacoco/test/html/index.html
```

**SonarQube** lee automáticamente los XMLs (`build/reports/jacoco/test/jacocoTestReport.xml`) para el Quality Gate.

### Mobile (jest)
```bash
cd mobile && npm run test:ci
open mobile/coverage/lcov-report/index.html
```

---

## Integración en CI/CD (Jenkins)

### Pipeline completo (Jenkinsfile.master)

```
Checkout → Prepare → Build JARs
    → Unit Tests (paralelo, 8 servicios)
    → Integration Tests (paralelo, 8 servicios)
    → Mobile Tests (jest + coverage)
    → Coverage Reports (JaCoCo + recordCoverage)
    → SonarQube Analysis → Quality Gate
    → Docker Build → Trivy Scan
    → Bootstrap → Approval (manual)
    → Deploy (Terraform/k8s)
    → Smoke Tests → E2E Tests → Performance Tests
    → Security Tests (OWASP ZAP)
    → Release Notes
```

### Artefactos generados por CI

| Artefacto | Stage que lo genera |
|---|---|
| `services/*/build/test-results/test/*.xml` | Unit Tests / Integration Tests |
| `mobile/junit.xml` | Mobile Tests |
| `mobile/coverage/` | Mobile Tests |
| `services/*/build/reports/jacoco/**/*.html` | Coverage Reports |
| `trivy-reports/*.html` | Trivy Scan |
| `locust/locust-report-master.html` | Performance Tests |
| `locust/locust-stats-master*.csv` | Performance Tests |
| `zap/reports/*.html`, `zap/reports/*.json` | Security Tests (OWASP ZAP) |
| `release-notes-vX.Y.Z.md` | Release Notes |

---

## Mapeo con el rubro (Punto 5 — Pruebas Completas)

| Requisito | Herramienta | Evidencia |
|---|---|---|
| Pruebas unitarias microservicios | JUnit 5 + Mockito | 49 archivos, `Unit Tests` stage |
| Pruebas de integración entre servicios | Spring Boot Test + Testcontainers | 10 archivos, `Integration Tests` stage |
| Pruebas E2E flujos completos | Bash + curl (`run_e2e.sh`) | 7 flujos, `E2E Tests` stage (master) |
| Pruebas de rendimiento y estrés (Locust) | Locust (`locustfile.py`) | 6 perfiles, SLA p95<500ms, `Performance Tests` stage |
| Pruebas de seguridad (OWASP ZAP) | ZAP Baseline (`run_zap.sh`) | 8 servicios, `Security Tests` stage (master) |
| Informes de cobertura | JaCoCo + jest-coverage | HTML/XML por servicio, `Coverage Reports` stage |
| Ejecución automatizada en pipelines | Jenkins (3 Jenkinsfiles) | dev/stage/prod con stages separados y artefactos |
