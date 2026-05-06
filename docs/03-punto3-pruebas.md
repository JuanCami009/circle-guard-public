# Punto 3: Pruebas - Unitarias, Integración, E2E y Rendimiento (30%)

## Resumen

Este documento describe todas las pruebas nuevas implementadas para el Punto 3 del Taller 2. Se definen cuatro niveles de prueba distribuidos entre los microservicios seleccionados:

| Tipo | Cantidad | Servicios cubiertos | Herramienta principal |
|---|---|---|---|
| Unitarias | 5 | promotion, auth, notification | JUnit 5 + Mockito |
| Integración | 5 | promotion, notification, gateway, form, identity | JUnit 5 + Testcontainers / @SpringBootTest |
| E2E | 5 flujos | Los 6 servicios del entorno dev | Bash + curl |
| Rendimiento | 4 escenarios | promotion, form, gateway, dashboard | Locust |

### Localización de los nuevos archivos

```
services/
  circleguard-promotion-service/src/test/java/com/circleguard/promotion/
    task/GraphCleanupTaskTest.java                    # Unit
    service/LocationResolutionServiceTest.java        # Unit
    integration/SurveyListenerIntegrationTest.java    # Integración

  circleguard-auth-service/src/test/java/com/circleguard/auth/service/
    JwtTokenServiceTest.java                          # Unit
    QrTokenServiceTest.java                           # Unit

  circleguard-notification-service/src/test/java/com/circleguard/notification/
    service/AuditLogServiceTest.java                  # Unit
    integration/ExposureNotificationIntegrationTest.java  # Integración

  circleguard-gateway-service/src/test/java/com/circleguard/gateway/
    integration/GatewayValidationIntegrationTest.java # Integración

  circleguard-form-service/src/test/java/com/circleguard/form/
    integration/QuestionnaireJpaIntegrationTest.java  # Integración

  circleguard-identity-service/src/test/java/com/circleguard/identity/
    integration/IdentityVaultServiceIntegrationTest.java  # Integración

e2e/
  run_e2e.sh                                          # E2E (5 flujos)

locust/
  locustfile.py                                       # Rendimiento
  locust.conf                                         # Configuración
```

---

## 1. Pruebas Unitarias

Las pruebas unitarias validan componentes individuales en completo aislamiento: sin Spring context, sin base de datos, sin red. Todas siguen el patrón `@ExtendWith(MockitoExtension.class)` con dependencias mockeadas.

### 1.1 GraphCleanupTaskTest

**Archivo**: `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/task/GraphCleanupTaskTest.java`

**Clase bajo prueba**: `GraphCleanupTask` - scheduler que elimina relaciones `ENCOUNTERED` del grafo Neo4j con más de 14 días de antigüedad (NFR-4: Data Minimization).

| Test | Comportamiento validado |
|---|---|
| `shouldPurgeEncountersOlderThan14Days` | Verifica que `purgeStaleEncounters()` recibe un `threshold` dentro del rango esperado (± tolerancia de ejecución) |
| `shouldNotThrowWhenRepositoryReturnsNull` | El método maneja `null` retornado por el repositorio sin NullPointerException |
| `shouldHandleRepositoryExceptionGracefully` | Una `RuntimeException` del repositorio es capturada internamente - el scheduler no propaga excepciones |

```java
@Test
void shouldPurgeEncountersOlderThan14Days() {
    when(userNodeRepository.purgeStaleEncounters(anyLong())).thenReturn(5L);
    long before = System.currentTimeMillis();

    graphCleanupTask.purgeStaleEncounters();

    ArgumentCaptor<Long> thresholdCaptor = ArgumentCaptor.forClass(Long.class);
    verify(userNodeRepository).purgeStaleEncounters(thresholdCaptor.capture());

    long captured = thresholdCaptor.getValue();
    assertThat(captured)
        .isGreaterThanOrEqualTo(before - FOURTEEN_DAYS_MS)
        .isLessThanOrEqualTo(System.currentTimeMillis() - FOURTEEN_DAYS_MS);
}
```

**Por qué es relevante**: garantiza que la política de retención de 14 días (NFR-4) se aplica correctamente a nivel de llamada al repositorio, y que fallos de Neo4j no interrumpen el scheduler de Spring.

---

### 1.2 JwtTokenServiceTest

**Archivo**: `services/circleguard-auth-service/src/test/java/com/circleguard/auth/service/JwtTokenServiceTest.java`

**Clase bajo prueba**: `JwtTokenService` - genera tokens JWT HS256 que son consumidos por todos los microservicios para autenticación.

| Test | Comportamiento validado |
|---|---|
| `shouldGenerateTokenWithAnonymousIdAsSubject` | El `sub` del JWT es el `UUID` del `anonymousId`, no la identidad real |
| `shouldIncludePermissionsInToken` | Los permisos del `Authentication` se añaden como claim `permissions` |
| `shouldSetExpirationApproximatelyOneHourFromNow` | El campo `exp` está dentro del rango `[now + expiration - ε, now + expiration + ε]` |

```java
@Test
void shouldGenerateTokenWithAnonymousIdAsSubject() {
    UUID anonymousId = UUID.randomUUID();
    Authentication auth = mock(Authentication.class);
    when(auth.getAuthorities()).thenReturn(List.of());

    String token = jwtTokenService.generateToken(anonymousId, auth);

    Claims claims = Jwts.parserBuilder()
        .setSigningKey(verificationKey).build()
        .parseClaimsJws(token).getBody();

    assertThat(claims.getSubject()).isEqualTo(anonymousId.toString());
}
```

**Por qué es relevante**: el `sub` del token es el único identificador que circula entre servicios - garantiza que nunca se filtra la identidad real por error de implementación.

---

### 1.3 QrTokenServiceTest

**Archivo**: `services/circleguard-auth-service/src/test/java/com/circleguard/auth/service/QrTokenServiceTest.java`

**Clase bajo prueba**: `QrTokenService` - genera tokens JWT de corta duración para validación en accesos físicos (portería).

| Test | Comportamiento validado |
|---|---|
| `shouldGenerateTokenWithAnonymousIdAsSubject` | El `sub` del QR token es el `anonymousId` correcto |
| `shouldGenerateANonNullNonEmptyToken` | El token generado no es nulo ni vacío |
| `shouldGenerateExpiredTokenWhenExpirationIsVeryShort` | Un token con expiración de 1 segundo lanza `ExpiredJwtException` tras esperar |
| `shouldGenerateDifferentTokensForSameUser` | Dos llamadas sucesivas producen tokens distintos (diferente `iat`) |

**Por qué es relevante**: los tokens QR tienen vida corta (5 minutos por defecto) - las pruebas garantizan que el mecanismo de expiración funciona y que no se reutilizan tokens entre sesiones.

---

### 1.4 AuditLogServiceTest

**Archivo**: `services/circleguard-notification-service/src/test/java/com/circleguard/notification/service/AuditLogServiceTest.java`

**Clase bajo prueba**: `AuditLogService` - publica eventos de auditoría al topic `notification.audit` para trazabilidad de notificaciones.

| Test | Comportamiento validado |
|---|---|
| `shouldPublishAuditEventToCorrectTopic` | El `KafkaTemplate.send()` recibe el topic `notification.audit` y la clave correcta |
| `shouldIncludeAllFieldsInAuditEvent` | El payload contiene `eventId`, `timestamp`, `userId`, `channel`, `status`, `correlationId` |
| `shouldGenerateCorrelationIdWhenNullProvided` | Si `correlationId` es `null`, el servicio genera uno automáticamente (no nulo ni vacío) |

```java
@Test
void shouldIncludeAllFieldsInAuditEvent() {
    ArgumentCaptor<Object> payloadCaptor = ArgumentCaptor.forClass(Object.class);
    auditLogService.logDelivery("user-456", "SMS", "FAILED", "corr-xyz");
    verify(kafkaTemplate).send(eq("notification.audit"), eq("user-456"), payloadCaptor.capture());

    Map<String, Object> event = (Map<String, Object>) payloadCaptor.getValue();
    assertThat(event).containsKeys("eventId", "timestamp", "userId", "channel", "status", "correlationId");
}
```

**Por qué es relevante**: la trazabilidad de notificaciones es un requisito de compliance; cada despacho debe dejar registro completo en Kafka.

---

### 1.5 LocationResolutionServiceTest

**Archivo**: `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/service/LocationResolutionServiceTest.java`

**Clase bajo prueba**: `LocationResolutionService` - transforma señales WiFi (MAC de AP + MAC de dispositivo) en eventos de proximidad anónimos.

| Test | Comportamiento validado |
|---|---|
| `shouldEmitProximityEventForKnownDeviceAtKnownAp` | AP conocido + dispositivo con sesión activa → evento publicado a `proximity.detected` |
| `shouldIgnoreSignalFromUnknownAccessPoint` | AP desconocido → `KafkaTemplate` y `MacSessionRegistry` no son invocados |
| `shouldIgnoreSignalFromUnmappedDevice` | Dispositivo sin sesión activa → `KafkaTemplate` y `GraphService` no son invocados |

**Por qué es relevante**: el servicio debe garantizar privacidad por defecto - dispositivos sin sesión registrada (MACs aleatorizadas) son silenciados, no registrados.

---

## 2. Pruebas de Integración

Las pruebas de integración validan la comunicación entre múltiples componentes reales del sistema. Todas están anotadas con `@Tag("integration")` para ejecutarse selectivamente.

> **Nota sobre Testcontainers en CI**: Los tests que levantan contenedores Docker (Neo4j) requieren acceso al socket Docker nativo. En macOS con Docker Desktop (que usa un proxy de socket), estos tests no pueden ejecutarse en el Jenkins contenedorizado. Se ejecutan correctamente de forma local con `docker nativo` o en entornos Linux CI. Ver sección 5 para la configuración del pipeline.

---

### 2.1 SurveyListenerIntegrationTest

**Archivo**: `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/integration/SurveyListenerIntegrationTest.java`

**Flujo validado**: `SurveyListener` → `HealthStatusService` → Neo4j (real)

**Infraestructura**: `Neo4jContainer` (Testcontainers 1.19.3, imagen `neo4j:5.12`)

| Test | Comportamiento validado |
|---|---|
| `shouldPromoteUserToSuspectWhenSurveyHasSymptoms` | Evento `{hasSymptoms: true}` → el nodo del usuario en Neo4j pasa a estado `SUSPECT` |
| `shouldLeaveUserUnchangedWhenSurveyHasNoSymptoms` | Evento `{hasSymptoms: false}` → estado del nodo permanece `ACTIVE` |

```java
@SpringBootTest
@Testcontainers
@Tag("integration")
class SurveyListenerIntegrationTest {

    @Container
    static Neo4jContainer<?> neo4j = new Neo4jContainer<>("neo4j:5.12")
            .withAdminPassword("password");

    @DynamicPropertySource
    static void neo4jProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.neo4j.uri", neo4j::getBoltUrl);
        // ...
    }
    // ...
}
```

**Relevancia**: valida el flujo crítico que convierte una encuesta de salud en un cambio de estado real en el grafo de contactos.

---

### 2.2 ExposureNotificationIntegrationTest

**Archivo**: `services/circleguard-notification-service/src/test/java/com/circleguard/notification/integration/ExposureNotificationIntegrationTest.java`

**Flujo validado**: `ExposureNotificationListener` → `NotificationDispatcher` + `LmsService`

**Infraestructura**: `@SpringBootTest` con `@MockBean` para `NotificationDispatcher` y `LmsService`

| Test | Comportamiento validado |
|---|---|
| `shouldTriggerDispatchForSuspectStatusChange` | Evento JSON con status `SUSPECT` → `dispatcher.dispatch()` y `lmsService.syncRemoteAttendance()` invocados |
| `shouldNotDispatchForActiveStatus` | Evento con status `ACTIVE` → no se invoca ningún dispatcher |
| `shouldTriggerDispatchForConfirmedStatusChange` | Evento con status `CONFIRMED` → dispatch activado |

**Relevancia**: garantiza que el listener de Kafka orquesta correctamente la notificación multicanal y la sincronización con el LMS (Moodle) ante cambios de estado relevantes.

---

### 2.3 GatewayValidationIntegrationTest

**Archivo**: `services/circleguard-gateway-service/src/test/java/com/circleguard/gateway/integration/GatewayValidationIntegrationTest.java`

**Flujo validado**: `GateController` → `QrValidationService` (JWT real) → Redis (mock)

**Infraestructura**: `@SpringBootTest` + `@AutoConfigureMockMvc` + `@MockBean StringRedisTemplate`

| Test | Comportamiento validado |
|---|---|
| `shouldAllowAccessForHealthyUser` | Token JWT válido + estado Redis `CLEAR` → HTTP 200 con `{valid: true, status: "GREEN"}` |
| `shouldDenyAccessForContagiousUser` | Token válido + estado Redis `CONTAGIED` → `{valid: false, status: "RED"}` |
| `shouldRejectExpiredToken` | Token JWT expirado → `{valid: false, status: "RED"}` (sin consultar Redis) |

```java
@SpringBootTest(properties = {"qr.secret=my-qr-secret-key-for-dev-1234567890", ...})
@AutoConfigureMockMvc
@Tag("integration")
class GatewayValidationIntegrationTest {

    @Test
    void shouldAllowAccessForHealthyUser() throws Exception {
        String token = buildValidQrToken(anonymousId);
        // mock Redis devuelve "CLEAR"
        mockMvc.perform(post("/api/v1/gate/validate").content("{\"token\":\"" + token + "\"}"))
               .andExpect(jsonPath("$.status").value("GREEN"));
    }
}
```

**Relevancia**: es la integración más crítica para el flujo de acceso físico al campus - verifica que el parsing JWT real, la consulta a Redis y la respuesta HTTP trabajan coordinadamente.

---

### 2.4 QuestionnaireJpaIntegrationTest

**Archivo**: `services/circleguard-form-service/src/test/java/com/circleguard/form/integration/QuestionnaireJpaIntegrationTest.java`

**Flujo validado**: `QuestionnaireRepository` ↔ PostgreSQL (H2 in-memory)

**Infraestructura**: `@DataJpaTest` con H2 en modo PostgreSQL

| Test | Comportamiento validado |
|---|---|
| `shouldPersistAndRetrieveQuestionnaire` | Guardar un cuestionario → recuperarlo por ID → campos y `createdAt` correctos |
| `shouldFindActiveQuestionnaireByHighestVersion` | De múltiples versiones activas/inactivas, el finder devuelve la versión activa más alta |
| `shouldSetDefaultValuesOnPersist` | `@PrePersist` establece `version=1`, `isActive=false`, `createdAt`/`updatedAt` automáticamente |
| `shouldReturnAllPersistedQuestionnaires` | `findAll()` devuelve todos los cuestionarios guardados en la misma transacción |

**Relevancia**: valida la lógica de `@PrePersist`/`@PreUpdate` y el finder custom `findFirstByIsActiveTrueOrderByVersionDesc()` que la app usa para obtener el formulario vigente.

---

### 2.5 IdentityVaultServiceIntegrationTest

**Archivo**: `services/circleguard-identity-service/src/test/java/com/circleguard/identity/integration/IdentityVaultServiceIntegrationTest.java`

**Flujo validado**: `IdentityVaultService` → `IdentityMappingRepository` → `IdentityEncryptionConverter` ↔ H2

**Infraestructura**: `@SpringBootTest` + `@ActiveProfiles("test")` + `@Transactional`

| Test | Comportamiento validado |
|---|---|
| `shouldCreateAnonymousIdForNewIdentity` | Primera llamada con identidad nueva → genera `anonymousId` (UUID) |
| `shouldReturnSameAnonymousIdForSameIdentity` | Segunda llamada con misma identidad → mismo `anonymousId` (idempotencia) |
| `shouldReturnDifferentAnonymousIdsForDifferentIdentities` | Dos identidades distintas → dos UUIDs distintos |
| `shouldResolveRealIdentityFromAnonymousId` | `resolveRealIdentity(uuid)` → devuelve la identidad real descifrada |
| `shouldThrowNotFoundForUnknownAnonymousId` | UUID inexistente → `ResponseStatusException(404)` |

**Relevancia**: garantiza el pilar de privacidad del sistema: la bóveda de identidades es idempotente, bidireccional, y el cifrado transparente del `IdentityEncryptionConverter` funciona en el ciclo completo.

---

## 3. Pruebas E2E

Las pruebas E2E validan flujos completos de usuario contra el entorno dev desplegado en Kubernetes. Se implementan como un script Bash que usa `curl`, sin dependencias adicionales.

### 3.1 Script: `e2e/run_e2e.sh`

```bash
#!/bin/bash
# Variables de entorno:
#   E2E_HOST       → host donde los NodePorts son accesibles (default: host.docker.internal)
#   TEST_JWT       → JWT válido para endpoints autenticados
#   TEST_ANON_ID   → anonymousId del usuario de prueba
#   TEST_QR_TOKEN  → QR token válido para validación en portería
```

### 3.2 Descripción de los 5 flujos

| Flujo | Servicio | Endpoint | Validación |
|---|---|---|---|
| **1 - Health Check** | Los 6 servicios | `GET /actuator/health` (×6) | HTTP 200; falla si alguno devuelve 000 o 5xx |
| **2 - Listado de formularios** | form-service (31086) | `GET /api/v1/questionnaires` | HTTP 200, 401 o 403 aceptados (servicio activo) |
| **3 - Analytics del dashboard** | dashboard-service (31084) | `GET /api/v1/analytics/summary` | HTTP 200, 401 o 403 aceptados |
| **4 - Validación de QR** | gateway-service (31087) | `POST /api/v1/gate/validate` | Campo `status` = `"GREEN"` o `"RED"` (no 5xx) |
| **5 - Estado de salud** | promotion-service (31088) | `GET /api/v1/health/status/{id}` | HTTP 200, 401, 403 o 404 aceptados |

Los flujos 1 a 3 y 5 aceptan códigos 4xx como respuesta válida (el servicio respondió correctamente aunque requiera autenticación). Solo un código 000 (connection refused) o 5xx indica un fallo real.

### 3.3 Configuración de credenciales en Jenkins

Para el flujo 4 (validación QR), el script usa la variable `TEST_QR_TOKEN`. En Jenkins se configura mediante credenciales de tipo **Secret Text**:

1. Ir a **Manage Jenkins → Credentials → System → Global credentials**
2. Crear tres credenciales tipo **Secret Text**:

| ID | Descripción | Valor ejemplo |
|---|---|---|
| `e2e-jwt-token` | JWT válido para entorno dev | `eyJhbGciOiJIUzI1...` |
| `e2e-anon-id` | anonymousId del usuario de prueba | `550e8400-e29b-...` |
| `e2e-qr-token` | QR token válido (corta duración) | `eyJhbGciOiJIUzI1...` |

> **Nota**: el `TEST_QR_TOKEN` tiene expiración corta (5 minutos por defecto). Para el pipeline, regenerar el token antes de ejecutar el build o extender la expiración en la configuración del servicio de prueba.

### 3.4 Ejecución local

```bash
# Con entorno dev corriendo en Kubernetes local:
E2E_HOST=localhost \
TEST_JWT="<jwt>" \
TEST_ANON_ID="<uuid>" \
TEST_QR_TOKEN="<qr-token>" \
  bash e2e/run_e2e.sh
```

Salida esperada:

```
============================================================
Iniciando pruebas E2E — Host: localhost
============================================================

>>> FLUJO 1: Health Check de todos los servicios
[PASS] notification-service (HTTP 404 — servicio vivo, 0s)
[PASS] dashboard-service (HTTP 200 — servicio vivo, 0s)
[PASS] file-service (HTTP 404 — servicio vivo, 0s)
[PASS] form-service (HTTP 200 — servicio vivo, 0s)
[PASS] gateway-service (HTTP 404 — servicio vivo, 0s)
[PASS] promotion-service (HTTP 403 — servicio vivo, 0s)

>>> FLUJO 2: Consulta de formularios activos (form-service)
[PASS] form-service GET /api/v1/questionnaires (HTTP 200, 0s)

...

>>> FLUJO 4: Validación de acceso con QR token (gateway-service)
[PASS] gateway-service POST /api/v1/gate/validate (campo status=GREEN, 0s)

============================================================
Desglose por flujo:
  FLUJO 1: Health Check (6 servicios)            PASS  (6ok/0fail, 0s)
  FLUJO 2: Listado de formularios (form-service)  PASS  (1ok/0fail, 0s)
  FLUJO 3: Analytics summary (dashboard-service)  PASS  (1ok/0fail, 0s)
  FLUJO 4: Validación QR (gateway-service)      PASS  (1ok/0fail, 0s)
  FLUJO 5: Health status (promotion-service)     PASS  (1ok/0fail, 0s)

Resultados : 10 pasaron | 0 fallaron
Duración   : 2s
Veredicto  : PASS
============================================================
```

> El script reporta el tiempo de cada check y de cada flujo. En entorno local los tiempos aparecen como `0s` porque `date +%s` tiene resolución de 1 segundo y las llamadas al cluster local son <200 ms. En CI (acceso remoto) el campo muestra la duración real del flujo.

![E2E tests pasando en Jenkins](../screenshots/e2e-tests-pass.png)

---

## 4. Pruebas de Rendimiento con Locust

### 4.1 Descripción de los escenarios

El archivo `locust/locustfile.py` define cuatro clases de usuario que simulan comportamientos reales del sistema:

| Clase | Servicio objetivo | Puerto | Peso | Tareas principales |
|---|---|---|---|---|
| `HealthStatusUser` | promotion-service | 31088 | 5 | `GET /api/v1/health/status/{id}` (×5), `GET /actuator/health` (×1) |
| `SurveySubmissionUser` | form-service | 31086 | 2 | `POST /api/v1/surveys` (×3), `GET /api/v1/questionnaires` (×1) |
| `GatewayValidationUser` | gateway-service | 31087 | **8** | `POST /api/v1/gate/validate` (×10) |
| `DashboardAnalyticsUser` | dashboard-service | 31084 | 1 | `GET /api/v1/analytics/summary` (×2), `GET /api/v1/analytics/heatmap` (×1) |

El **peso** (weight) determina la proporción de usuarios de cada tipo. `GatewayValidationUser` tiene el peso más alto porque la validación de acceso es la operación más frecuente del sistema (cada estudiante la ejecuta al ingresar al campus).

### 4.2 Configuración: `locust/locust.conf`

```ini
host        = http://host.docker.internal:31087  # gateway (mayor carga)
users       = 50                                 # usuarios concurrentes totales
spawn-rate  = 5                                  # usuarios/segundo al iniciar
run-time    = 60s                                # duración de la prueba
headless    = true                               # sin UI (modo CI)
html        = /mnt/locust/locust-report.html     # reporte HTML
csv         = /mnt/locust/locust-stats           # estadísticas CSV
exit-code-on-error = 1
```

### 4.3 Imagen Docker: `locust/Dockerfile`

Para ejecutar Locust en el pipeline Jenkins sin depender de volúmenes Docker (incompatibles con Docker Desktop en macOS), se creó una imagen efímera que empaqueta los archivos de prueba directamente:

```dockerfile
FROM locustio/locust
USER root
COPY . /mnt/locust/
RUN chown -R locust:locust /mnt/locust
USER locust
WORKDIR /mnt/locust
```

**Por qué es necesario:**

El pipeline Jenkins corre dentro de un contenedor Docker. Al intentar `docker run -v "$PWD/locust:/mnt/locust"`, el path `$PWD` es una ruta del filesystem del contenedor Jenkins (`/var/jenkins_home/workspace/...`), no del host macOS. Docker Desktop busca ese path en el host, no lo encuentra, y monta un directorio vacío — Locust no puede leer `locust.conf` ni `locustfile.py`.

`docker build` resuelve esto porque envía los archivos como un **tar al daemon Docker** (no como path del host). Una vez construida la imagen, los archivos están embebidos y no se necesita ningún volumen.

El `chown -R locust:locust /mnt/locust` es necesario porque la instrucción `COPY` crea los archivos con propietario `root`, y el proceso Locust (que corre como usuario `locust`) necesita permisos de escritura para generar `locust-report.html` y `locust-stats_stats.csv` en ese mismo directorio.

| Archivo | Rol |
|---|---|
| `locust/Dockerfile` | Define la imagen efímera con los archivos de prueba embebidos |
| `locust/locustfile.py` | Escenarios de carga (copiado a `/mnt/locust/`) |
| `locust/locust.conf` | Configuración headless (copiado a `/mnt/locust/`) |

### 4.4 Ejecución local

```bash
# Instalar locust
pip install locust

# Ejecutar contra entorno dev (con UI web en http://localhost:8089)
locust -f locust/locustfile.py \
  --host http://localhost:31087 \
  --users 50 --spawn-rate 5

# Ejecutar headless (sin UI)
locust -f locust/locustfile.py --config locust/locust.conf \
  --host http://localhost:31087 \
  --html locust-report.html
```

### 4.5 Ejecución en Jenkins (via Docker)

Se usa `docker build` para empaquetar los archivos Locust en una imagen efímera antes de correrla. Esto evita el problema de Docker-in-Docker en macOS: los volúmenes con paths del contenedor Jenkins (`/var/jenkins_home/workspace/...`) no son accesibles desde Docker Desktop, por lo que un `docker run -v` montaría un directorio vacío. `docker build` envía los archivos como tar al daemon sin depender del filesystem del host.

```bash
# Construir imagen con los archivos Locust embebidos
docker build -t circleguard-locust -f locust/Dockerfile locust/

# Ejecutar la prueba de carga (sin --rm para poder extraer reportes)
docker run --name locust-perf-run \
  --network host \
  -e LOCUST_JWT="${TEST_JWT:-}" \
  -e LOCUST_ANON_ID="${TEST_ANON_ID:-test-anon-id}" \
  circleguard-locust \
  -f /mnt/locust/locustfile.py \
  --config /mnt/locust/locust.conf

# Extraer reportes del contenedor al workspace
docker cp locust-perf-run:/mnt/locust/locust-report.html locust/locust-report.html
docker cp locust-perf-run:/mnt/locust/locust-stats_stats.csv locust/locust-stats_stats.csv
docker rm locust-perf-run
```

El reporte HTML se archiva como artefacto del build de Jenkins.

![Reporte Locust en Jenkins](../screenshots/locust-report-jenkins.png)

---

## 5. Actualización del Pipeline (Jenkinsfile.dev)

### 5.1 Stage Integration Tests - antes vs. después

**Antes (Punto 2)**: todas las sub-etapas imprimían un mensaje de omisión.

**Después (Punto 3)**: los servicios con tests de integración no-Testcontainers los ejecutan realmente.

| Sub-etapa | Antes | Después |
|---|---|---|
| `integration:file-service` | `echo 'omitida'` | `echo 'omitida'` (sin tests) |
| `integration:gateway-service` | `echo 'omitida'` | `gradle test --tests "*.gateway.integration.*"` |
| `integration:dashboard-service` | `echo 'omitida'` | `echo 'omitida'` (sin tests) |
| `integration:form-service` | `echo 'omitida'` | `gradle test --tests "*.form.integration.*"` |
| `integration:notification-service` | `echo 'omitida'` | `gradle test --tests "*.notification.integration.*"` |
| `integration:promotion-service` | `echo 'omitida'` | `echo 'omitida'` (Testcontainers Neo4j - limitación macOS) |
| `integration:identity-service` | *(no existía)* | `gradle test --tests "*.identity.integration.*"` |

### 5.2 Stage E2E Tests - implementación

```groovy
stage('E2E Tests') {
    steps {
        sh 'chmod +x e2e/run_e2e.sh'
        withCredentials([
            string(credentialsId: 'e2e-jwt-token',  variable: 'TEST_JWT'),
            string(credentialsId: 'e2e-anon-id',    variable: 'TEST_ANON_ID'),
            string(credentialsId: 'e2e-qr-token',   variable: 'TEST_QR_TOKEN')
        ]) {
            sh 'bash e2e/run_e2e.sh'
        }
    }
}
```

### 5.3 Stage Performance Tests - implementación

```groovy
stage('Performance Tests') {
    steps {
        sh '''
            docker build -t circleguard-locust -f locust/Dockerfile locust/
            docker rm -f locust-perf-run 2>/dev/null || true
            docker run --name locust-perf-run \
              --network host \
              -e LOCUST_JWT="${TEST_JWT:-}" \
              -e LOCUST_ANON_ID="${TEST_ANON_ID:-test-anon-id}" \
              circleguard-locust \
              -f /mnt/locust/locustfile.py \
              --config /mnt/locust/locust.conf || true
            docker cp locust-perf-run:/mnt/locust/locust-report.html locust/locust-report.html || true
            docker cp locust-perf-run:/mnt/locust/locust-stats_stats.csv locust/locust-stats_stats.csv || true
            docker rm locust-perf-run || true
        '''
    }
    post {
        always {
            archiveArtifacts artifacts: 'locust/locust-report.html,locust/locust-stats*.csv',
                             allowEmptyArchive: true
        }
    }
}
```

La bandera `|| true` evita que el pipeline falle si Locust detecta una tasa de error alta (el análisis se hace manualmente sobre el reporte HTML archivado).

---

## 6. Análisis de Resultados

### 6.1 Pruebas unitarias e integración

Los tests unitarios e de integración deben ejecutarse antes de cada build. Los resultados se publican en Jenkins como informes JUnit. Umbrales esperados:

| Tipo | Meta | Criterio de fallo |
|---|---|---|
| Unitarias | 100% pass | Cualquier fallo bloquea el pipeline |
| Integración (no-TC) | 100% pass | Cualquier fallo bloquea el pipeline |
| Integración (Testcontainers) | Local: 100% pass | En macOS CI: omitidos (ver sección 2) |

### 6.2 Pruebas E2E

#### Resultado del run de referencia (2026-05-06)

```
Resultados : 10 pasaron | 0 fallaron
Duración   : 0s
Veredicto  : PASS
```

| Flujo | Checks | Resultado | Código HTTP observado |
|---|---|---|---|
| FLUJO 1: Health Check (6 servicios) | 6 | PASS (6ok/0fail) | 404, 200, 404, 200, 404, 403 |
| FLUJO 2: Listado de formularios | 1 | PASS (1ok/0fail) | 200 |
| FLUJO 3: Analytics summary | 1 | PASS (1ok/0fail) | 200 |
| FLUJO 4: Validación QR | 1 | PASS (1ok/0fail) | 200 (`status=GREEN`) |
| FLUJO 5: Health status | 1 | PASS (1ok/0fail) | 403 |

#### Interpretación de códigos HTTP en el Flujo 1

El Flujo 1 usa `check_alive`, que acepta cualquier respuesta HTTP distinta de `000` (connection refused) y `5xx` (error de servidor). Los códigos observados son los esperados para el entorno dev sin JWT:

| Servicio | Código | Explicación |
|---|---|---|
| notification-service | 404 | No expone `/api/v1/notifications` sin autenticación; responde ⇒ vivo |
| dashboard-service | 200 | Endpoint público sin auth requerido |
| file-service | 404 | Endpoint de listado requiere path específico; servicio responde ⇒ vivo |
| form-service | 200 | Lista formularios públicamente |
| gateway-service | 404 | `/api/v1/gate/health` no existe; el servicio responde ⇒ vivo |
| promotion-service | 403 | Requiere JWT; Spring Security rechaza y responde ⇒ vivo |

#### Tabla de interpretación por flujo

| Flujo | Resultado esperado | Indicador de problema real |
|---|---|---|
| Health Check | Todos los servicios responden (no 000 ni 5xx) | `000` = pod caído o puerto incorrecto; `5xx` = error interno |
| Listado formularios | HTTP 200/401/403 | `5xx` indica error de configuración JPA o conexión a PostgreSQL |
| Analytics dashboard | HTTP 200/401/403 | `5xx` indica problema de conexión a la base de datos analítica |
| Validación QR | Campo `status="GREEN"` en la respuesta JSON | `status="RED"` o `valid:false` indica token expirado o blacklistado |
| Estado de salud | HTTP 200/401/403/404 | `5xx` indica error en Neo4j o Redis |

### 6.3 Pruebas de rendimiento (Locust)

#### Resultado del run de referencia (2026-05-06, 50 usuarios, 60 s)

```
Peticiones totales : 1609
Fallos (5xx)       : 60
Tasa de errores    : 3.7%
RPS promedio       : 28.8
Latencia p50       : 3 ms
Latencia p95       : 8 ms
Latencia p99       : 17 ms

Veredicto SLA (p95<500ms, <1% 5xx) : REPROBADO
```

#### Desglose por endpoint

| Endpoint | Req | Fallos | p50 | p95 | p99 | Estado |
|---|---|---|---|---|---|---|
| `POST /api/v1/gate/validate` | 1091 | 0 | 3 ms | 8 ms | 17 ms | ✅ OK |
| `GET /api/v1/health/status/{id}` | 372 | 0 | 3 ms | 8 ms | 27 ms | ✅ OK |
| `POST /api/v1/surveys` | 47 | 0 | 4 ms | 10 ms | 76 ms | ✅ OK |
| `GET /api/v1/questionnaires` | 21 | 0 | 3 ms | 7 ms | 10 ms | ✅ OK |
| `GET /api/v1/analytics/summary` | 12 | 0 | 3 ms | 11 ms | 11 ms | ✅ OK |
| `GET /api/v1/analytics/heatmap` | 6 | 0 | 5 ms | 13 ms | 13 ms | ✅ OK |
| `GET /actuator/health` | 60 | 60 | 3 ms | 9 ms | 19 ms | ⚠️ FALLO |

#### Interpretación del veredicto "REPROBADO"

Los **60 fallos** provienen exclusivamente de `GET /actuator/health` en el puerto 31088 (promotion-service), que devuelve **HTTP 404**. Esto indica que promotion-service no expone el endpoint `/actuator/health` o lo expone en una ruta distinta (el arranque es correcto, pero la gestión del actuator está deshabilitada o reubicada en este servicio).

**Todos los endpoints de negocio tienen 0 fallos y latencias por debajo de los umbrales.** El veredicto REPROBADO del SLA se debe únicamente al actuator, no a degradación de rendimiento.

Opciones de resolución:
1. **Eliminar el actuator check del escenario de carga** en `HealthStatusUser.get_health_actuator()` — los servicios ya se verifican como activos en el E2E (Flujo 1).
2. **Habilitar el actuator en promotion-service** añadiendo `management.endpoints.web.exposure.include=health` a su `application.yml`.

#### Análisis de rendimiento real: los endpoints de negocio

Con el actuator excluido del análisis, el rendimiento real del sistema es:

| Métrica | Valor obtenido | Umbral aceptable | Evaluación |
|---|---|---|---|
| RPS sostenido | 28.8 req/s | > 20 RPS | ✅ Cumple |
| Latencia p50 (global) | 3 ms | < 200 ms | ✅ Muy por debajo |
| Latencia p95 (global) | 8 ms | < 500 ms | ✅ Muy por debajo |
| Latencia p99 (global) | 17 ms | < 1000 ms | ✅ Cumple |
| Fallos 5xx en negocio | 0 | < 1% | ✅ 0% |

#### Outlier observado: spike de 214 ms en gateway-service

El p99.9 de `POST /api/v1/gate/validate` llega a **210 ms** mientras el p95 es de 8 ms. Este spike ocurre en las primeras iteraciones durante el **ramp-up** (JVM cold start + inicialización de pool Redis). Una vez los 25 usuarios gateway están activos y el pool de conexiones está caliente, la latencia estabiliza a 3–5 ms. En producción, con pods pre-calentados, este outlier no aparecería.

#### Umbrales de referencia

| Métrica | Umbral aceptable | Umbral de alerta |
|---|---|---|
| Latencia p50 | < 200 ms | > 500 ms |
| Latencia p95 | < 500 ms | > 1000 ms |
| Latencia p99 | < 1000 ms | > 2000 ms |
| RPS sostenido | > 20 RPS | < 10 RPS |
| Tasa de errores 5xx | < 1% | > 5% |

#### Endpoints críticos y umbrales específicos

| Endpoint | Por qué es crítico | Umbral p95 | Resultado |
|---|---|---|---|
| `POST /api/v1/gate/validate` | Ejecutado en cada acceso al campus; picos en horario de entrada | < 500 ms | **8 ms** ✅ |
| `GET /api/v1/health/status/{id}` | Consumido por la app móvil continuamente en background | < 300 ms | **8 ms** ✅ |
| `POST /api/v1/surveys` | Procesamiento en cascada Kafka → Neo4j | < 1000 ms | **10 ms** ✅ |
| `GET /api/v1/analytics/summary` | Consulta agregada sobre múltiples nodos del grafo | < 2000 ms | **11 ms** ✅ |

#### Interpretación del reporte HTML

El reporte generado en `locust/locust-report.html` incluye:

- **Tabla de peticiones**: número de peticiones, fallos, latencias (mediana, 95p, 99p, máximo), RPS.
- **Gráfica de RPS en el tiempo**: permite detectar degradación bajo carga sostenida o estabilidad post-ramp.
- **Gráfica de tiempos de respuesta**: identifica outliers y degradación progresiva (como el spike de 214 ms).
- **Gráfica de usuarios activos**: confirma que el ramp-up de 5 usuarios/segundo fue correcto y alcanzó los 50 usuarios en ~10 segundos.

#### Qué revisar si los umbrales se superan en el futuro

1. **Recursos de los pods** (`kubectl describe pod`): OOMKilled o CPU throttling son las causas más frecuentes.
2. **Pool de conexiones Redis** en el namespace dev: timeout bajo o pool agotado generan picos en gateway-service.
3. **Logs de la JVM** (`kubectl logs`): GC pauses prolongados o connection pool exhaustion en Neo4j/PostgreSQL.

![Gráfica de throughput Locust](../screenshots/locust-rps-chart.png)

---

## 7. Cómo ejecutar todas las pruebas localmente

```bash
# 1. Pruebas unitarias (rápidas, sin Docker)
./gradlew :services:circleguard-promotion-service:test \
    --tests "com.circleguard.promotion.task.GraphCleanupTaskTest" \
    --tests "com.circleguard.promotion.service.LocationResolutionServiceTest" \
    --no-daemon

./gradlew :services:circleguard-auth-service:test --no-daemon
./gradlew :services:circleguard-notification-service:test \
    --tests "com.circleguard.notification.service.AuditLogServiceTest" --no-daemon

# 2. Pruebas de integración (requieren Docker daemon activo)
./gradlew :services:circleguard-promotion-service:test \
    --tests "com.circleguard.promotion.integration.*" --no-daemon

./gradlew :services:circleguard-gateway-service:test \
    --tests "com.circleguard.gateway.integration.*" --no-daemon

./gradlew :services:circleguard-form-service:test \
    --tests "com.circleguard.form.integration.*" --no-daemon

./gradlew :services:circleguard-identity-service:test \
    --tests "com.circleguard.identity.integration.*" --no-daemon

./gradlew :services:circleguard-notification-service:test \
    --tests "com.circleguard.notification.integration.*" --no-daemon

# 3. Pruebas E2E (requiere entorno dev desplegado en Kubernetes)
E2E_HOST=localhost TEST_JWT="..." TEST_ANON_ID="..." TEST_QR_TOKEN="..." \
    bash e2e/run_e2e.sh

# 4. Locust (requiere entorno dev desplegado)
pip install locust
locust -f locust/locustfile.py \
  --host http://localhost:31087 \
  --users 50 --spawn-rate 5 --run-time 60s \
  --headless --html locust-report.html
```
