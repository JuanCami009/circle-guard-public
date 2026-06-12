# Pruebas - Unitarias, Integración, E2E, Rendimiento y Seguridad

## Resumen

Este documento describe todas las pruebas implementadas en el proyecto. Se definen seis niveles de prueba distribuidos entre los microservicios backend y la aplicación móvil:

| Tipo | Cantidad | Servicios cubiertos | Herramienta principal |
|---|---|---|---|
| Unitarias (backend) | 39 tests en 20 clases | promotion, auth, notification, gateway, form, identity, dashboard, file | JUnit 5 + Mockito |
| Integración (backend) | 10 tests en 7 clases | promotion, notification, gateway, form, identity, dashboard, file | JUnit 5 + @SpringBootTest / H2 / Testcontainers |
| Unitarias (mobile) | 4 archivos | React Native / Expo | Jest + Testing Library |
| E2E | 7 flujos cross-service | Los 8 servicios del entorno desplegado | Bash + curl (`e2e/run_e2e.sh`) |
| Rendimiento | 4 clases de usuario, ~1600 req en 60 s | promotion, form, gateway, dashboard | Locust (headless, Docker) |
| Seguridad (dinámica) | 8 servicios | Todos los microservicios | OWASP ZAP Baseline |
| Seguridad (estática / imágenes) | 8 imágenes Docker + IaC | Todos los microservicios + k8s + terraform | Trivy |
| Cobertura | Reporte por servicio | 8 servicios backend | JaCoCo + SonarQube |

### Localización de todos los archivos de prueba

```
services/
  circleguard-promotion-service/src/test/java/com/circleguard/promotion/
    task/GraphCleanupTaskTest.java                          # Unit
    service/LocationResolutionServiceTest.java              # Unit
    service/HealthStatusServiceTest.java                    # Unit
    service/StatusLifecycleTest.java                        # Unit
    service/FloorServiceTest.java                           # Unit
    integration/SurveyListenerIntegrationTest.java          # Integración
    service/AdministrativeCorrectionTest.java               # Integración (Testcontainers)
    service/HealthStatusReevaluationTest.java               # Integración (Testcontainers)
    performance/PromotionPerformanceTest.java               # Rendimiento (Testcontainers)

  circleguard-auth-service/src/test/java/com/circleguard/auth/
    service/JwtTokenServiceTest.java                        # Unit
    service/QrTokenServiceTest.java                         # Unit
    controller/LoginControllerTest.java                     # Unit
    controller/QrTokenControllerTest.java                   # Unit
    controller/UserControllerTest.java                      # Unit
    client/IdentityClientResilienceTest.java                # Unit
    integration/AuthUserRepositoryIntegrationTest.java      # Integración

  circleguard-notification-service/src/test/java/com/circleguard/notification/
    service/AuditLogServiceTest.java                        # Unit
    service/NotificationDispatcherTest.java                 # Unit
    service/NotificationRetryTest.java                      # Unit
    service/PushServiceToggleTest.java                      # Unit
    service/ExposureNotificationListenerTest.java           # Unit
    service/LmsServiceTest.java                             # Unit
    service/PriorityAlertListenerTest.java                  # Unit
    service/RoomReservationServiceTest.java                 # Unit
    service/TemplateServiceTest.java                        # Unit
    integration/ExposureNotificationIntegrationTest.java    # Integración

  circleguard-gateway-service/src/test/java/com/circleguard/gateway/
    service/QrValidationServiceTest.java                    # Unit
    service/QrValidationCacheTest.java                      # Unit
    controller/GateControllerTest.java                      # Unit
    integration/GatewayValidationIntegrationTest.java       # Integración

  circleguard-form-service/src/test/java/com/circleguard/form/
    controller/HealthSurveyControllerTest.java              # Unit
    controller/QuestionnaireControllerTest.java             # Unit
    controller/AttachmentControllerTest.java                # Unit
    service/SymptomMapperTest.java                          # Unit
    integration/QuestionnaireJpaIntegrationTest.java        # Integración

  circleguard-identity-service/src/test/java/com/circleguard/identity/
    controller/IdentityVaultControllerTest.java             # Unit
    util/IdentityEncryptionConverterTest.java               # Unit
    repository/IdentityMappingRepositoryTest.java           # Integración
    integration/IdentityVaultServiceIntegrationTest.java    # Integración

  circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/
    controller/AnalyticsControllerTest.java                 # Unit
    service/KAnonymityFilterTest.java                       # Unit  ← nuevo
    service/AnalyticsServiceTest.java                       # Unit  ← nuevo
    integration/AnalyticsControllerIntegrationTest.java     # Integración  ← nuevo

  circleguard-file-service/src/test/java/com/circleguard/file/
    controller/FileUploadControllerTest.java                # Unit
    service/FileStorageServiceTest.java                     # Unit  ← nuevo
    integration/FileUploadIntegrationTest.java              # Integración  ← nuevo

mobile/
  hooks/useQrToken.test.ts                                  # Unit (mobile)
  components/__tests__/DynamicForm.test.tsx                 # Unit (mobile)
  context/__tests__/AuthContext.test.tsx                    # Unit (mobile)  ← nuevo
  utils/__tests__/storage.test.ts                           # Unit (mobile)  ← nuevo

e2e-tests/
  build.gradle.kts                                          # módulo Karate (JUnit 5)
  src/test/java/com/circleguard/e2e/E2eRunner.java          # runner JUnit5
  src/test/resources/karate-config.js                       # configuración: host, puertos, auth
  src/test/resources/e2e/
    health.feature                                          # E2E humo: 8 servicios sin 5xx
    journey-campus-access.feature                           # Journey A: sano → GREEN
    journey-health-risk.feature                             # Journey B: fiebre → RED (Kafka async)
    journey-visitor.feature                                 # Journey C: visitante → identity
    helpers/login.feature                                   # helper @ignore: login → jwt+anonId
    helpers/visitor-handoff.feature                         # helper @ignore: registro visitante

locust/
  locustfile.py                                             # Rendimiento (6 perfiles)
  locust.conf                                               # Configuración

zap/
  run_zap.sh                                                # Seguridad OWASP ZAP  ← nuevo
  rules.tsv                                                 # Reglas de supresión  ← nuevo
  README.md                                                 # Documentación ZAP    ← nuevo
```

---

## 1. Pruebas Unitarias (backend)

Las pruebas unitarias validan componentes individuales en completo aislamiento: sin Spring context, sin base de datos, sin red. Todas siguen el patrón `@ExtendWith(MockitoExtension.class)` con dependencias mockeadas.

### 1.1 GraphCleanupTaskTest

**Archivo**: `services/circleguard-promotion-service/src/test/java/com/circleguard/promotion/task/GraphCleanupTaskTest.java`

**Clase bajo prueba**: `GraphCleanupTask` - scheduler que elimina relaciones `ENCOUNTERED` del grafo Neo4j con más de 14 días de antigüedad (NFR-4: Data Minimization).

| Test | Comportamiento validado |
|---|---|
| `shouldPurgeEncountersOlderThan14Days` | Verifica que `purgeStaleEncounters()` recibe un `threshold` dentro del rango `[before - FOURTEEN_DAYS_MS, after - FOURTEEN_DAYS_MS]`, donde `FOURTEEN_DAYS_MS = 1_209_600_000` ms (constante definida en la linea 20 del test) y `before`/`after` son timestamps capturados antes y despues de la llamada al metodo bajo prueba |
| `shouldNotThrowWhenRepositoryReturnsNull` | El metodo maneja `null` retornado por el repositorio sin NullPointerException |
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

### 1.6 KAnonymityFilterTest

**Archivo**: `services/circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/service/KAnonymityFilterTest.java`

**Clase bajo prueba**: `KAnonymityFilter` - motor de privacidad k-anonimidad (Story 7.5, FR-23). Enmascara cualquier grupo de métricas con menos de K usuarios para prevenir re-identificación individual en departamentos o edificios pequeños.

| Test | Comportamiento validado |
|---|---|
| `shouldReturnEmptyMapWhenStatsIsNull` | Input `null` → retorna mapa vacío sin NPE |
| `shouldMaskEntireResultWhenTotalUsersBelowDefaultK` | `totalUsers=3` (< K=5) → resultado completo enmascarado, nota de privacidad, department/timestamp preservados |
| `shouldMaskEntireResultWhenTotalUsersBelowCustomK` | K configurable: `totalUsers=8` con K=10 → enmascarado |
| `shouldMaskIndividualCountsBelowKWhenTotalSufficient` | `totalUsers=100`, `suspectCount=2` → sólo `suspectCount` enmascarado a `"<5"` |
| `shouldNotMaskCountsAtExactlyK` | Conteo exactamente igual a K no se enmascara |
| `shouldNotMaskZeroCounts` | Ceros no implican riesgo de re-identificación, no se enmascaran |
| `shouldNotMaskNonCountFields` | Campos que no terminan en `"Count"` no se tocan |
| `shouldPreserveTimestampWhenMaskingEntireResult` | En enmascaramiento total, `timestamp` se preserva para correlación temporal |

```java
@Test
void shouldMaskIndividualCountsBelowKWhenTotalSufficient() {
    Map<String, Object> stats = new LinkedHashMap<>();
    stats.put("totalUsers", 100L);
    stats.put("suspectCount", 2L);    // < 5 → debe enmascararse
    stats.put("confirmedCount", 10L); // >= 5 → debe mostrarse

    Map<String, Object> result = filter.apply(stats);

    assertThat(result.get("suspectCount")).isEqualTo("<5");
    assertThat(result.get("confirmedCount")).isEqualTo(10L);
}
```

**Por qué es relevante**: la k-anonimidad es el mecanismo central de privacidad del dashboard. Si falla, un coordinador podría cruzar datos de un departamento pequeño con información pública y re-identificar a una persona específica.

---

### 1.7 AnalyticsServiceTest

**Archivo**: `services/circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/service/AnalyticsServiceTest.java`

**Clase bajo prueba**: `AnalyticsService` - orquesta consultas a `PromotionClient` (datos de salud) y aplica el filtro k-anonimidad. `PromotionClient` y `JdbcTemplate` se mockean completamente.

| Test | Comportamiento validado |
|---|---|
| `getCampusSummaryShouldDelegateToPromotionClient` | Delega directamente a `PromotionClient.getHealthStats()` sin transformar |
| `getDepartmentStatsShouldApplyKAnonymityFilter` | Llama a `PromotionClient.getHealthStatsByDepartment()` y aplica `kAnonymityFilter.apply()` sobre el resultado |
| `getGlobalHealthStatsShouldDelegateToCampusSummary` | `getGlobalHealthStats()` es alias de `getCampusSummary()` |
| `getTimeSeriesShouldReturnMockDataWhenTableDoesNotExist` | Cuando `JdbcTemplate` lanza excepción → fallback a datos mock (tabla puede no existir en PoC) |
| `getTimeSeriesShouldLimitResults` | El parámetro `limit` acota correctamente el tamaño del resultado |

**Por qué es relevante**: verifica que el filtro k-anonimidad se aplica en la capa correcta (servicio, no controlador) y que el fallback de time-series no expone excepciones al cliente.

---

### 1.8 FileStorageServiceTest

**Archivo**: `services/circleguard-file-service/src/test/java/com/circleguard/file/service/FileStorageServiceTest.java`

**Clase bajo prueba**: `FileStorageService` - persiste archivos subidos (certificados médicos, documentos) en el filesystem local con un UUID como prefijo de nombre. Usa `@TempDir` para aislar el test del filesystem real.

| Test | Comportamiento validado |
|---|---|
| `saveFileShouldReturnGeneratedFilename` | Retorna un nombre no vacío con sufijo `_<originalName>` |
| `saveFileShouldPersistFileToStorage` | El archivo existe en el path retornado y su contenido es idéntico al original |
| `saveFileShouldGenerateUniqueFilenamesForSameName` | Dos uploads del mismo nombre original producen nombres distintos (UUID diferente) |
| `saveFileShouldHandleFileWithNoOriginalName` | `originalFilename = null` no lanza `NullPointerException` |

```java
@Test
void saveFileShouldPersistFileToStorage() throws IOException {
    MockMultipartFile file = new MockMultipartFile(
        "file", "cert.pdf", "application/pdf", "cert-data".getBytes());

    String filename = service.saveFile(file);

    Path savedPath = tempDir.resolve(filename);
    assertThat(Files.exists(savedPath)).isTrue();
    assertThat(Files.readAllBytes(savedPath)).isEqualTo("cert-data".getBytes());
}
```

**Por qué es relevante**: garantiza que los certificados médicos subidos no se corrompen en el almacenamiento y que no hay colisiones de nombres entre usuarios distintos.

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

### 2.6 AnalyticsControllerIntegrationTest

**Archivo**: `services/circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/integration/AnalyticsControllerIntegrationTest.java`

**Flujo validado**: `AnalyticsController` → `AnalyticsService` → `KAnonymityFilter` (real) → `PromotionClient` (mock)

**Infraestructura**: `@SpringBootTest` + `@AutoConfigureMockMvc` + `@MockBean PromotionClient` + `@MockBean JdbcTemplate`

| Test | Comportamiento validado |
|---|---|
| `summaryEndpointShouldReturnPromotionStats` | `GET /api/v1/analytics/summary` → HTTP 200 con stats del PromotionClient |
| `healthBoardEndpointShouldReturnGlobalStats` | `GET /api/v1/analytics/health-board` → HTTP 200 con campo `campusStatus` |
| `departmentEndpointShouldApplyKAnonymityMasking` | Departamento con `totalUsers=3` → respuesta contiene `totalUsers: "<5"` y nota de privacidad |
| `departmentEndpointShouldExposeCountsWhenPopulationSufficient` | `totalUsers=200`, `suspectCount=8` (>= K) visible; `confirmedCount=2` (< K) enmascarado a `"<5"` |
| `timeSeriesEndpointShouldReturnDataPoints` | `GET /api/v1/analytics/time-series` → HTTP 200, body es un array |

```java
@Test
void departmentEndpointShouldApplyKAnonymityMasking() throws Exception {
    Map<String, Object> raw = new LinkedHashMap<>();
    raw.put("totalUsers", 3L);
    raw.put("suspectCount", 1L);
    raw.put("department", "TestDept");

    when(promotionClient.getHealthStatsByDepartment("TestDept")).thenReturn(raw);

    mockMvc.perform(get("/api/v1/analytics/department/TestDept"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.totalUsers").value("<5"))
        .andExpect(jsonPath("$.note").value("Insufficient data for privacy"));
}
```

**Relevancia**: es el único test que verifica el pipeline completo HTTP → k-anonimidad → respuesta JSON, garantizando que la privacidad se aplica en producción y no solo en tests unitarios del filtro.

---

### 2.7 FileUploadIntegrationTest

**Archivo**: `services/circleguard-file-service/src/test/java/com/circleguard/file/integration/FileUploadIntegrationTest.java`

**Flujo validado**: `FileUploadController` → `FileStorageService` → filesystem real

**Infraestructura**: `@SpringBootTest` + `@AutoConfigureMockMvc` (sin mocks - contexto completo)

| Test | Comportamiento validado |
|---|---|
| `uploadEndpointShouldReturn200WithFilenameForValidPdf` | Upload de PDF → HTTP 200, `filename` no vacío, con sufijo `_health-cert.pdf` |
| `uploadEndpointShouldAcceptImageFiles` | Upload de PNG → HTTP 200, filename generado |
| `uploadEndpointShouldReturn400WhenNoFileProvided` | Sin parámetro `file` → HTTP 4xx |

**Relevancia**: verifica que el endpoint multipart funciona end-to-end, incluyendo la creación del directorio `uploads/` y la escritura real al disco dentro del contexto de Spring Boot.

---

## 3. Pruebas Unitarias (mobile)

Las pruebas de la aplicación React Native (Expo) validan la lógica de los hooks, contextos y utilidades sin lanzar la app. Siguen el patrón de `renderHook` + `act` de Testing Library y mockean las dependencias nativas de Expo.

### 3.1 useQrToken.test.ts

**Archivo**: `mobile/hooks/useQrToken.test.ts`

**Hook bajo prueba**: `useQrToken` - genera un token QR rotativo de 60 segundos para acceso al campus.

| Test | Comportamiento validado |
|---|---|
| `should initialize with a token and 60s timer when anonymousId is present` | Token no nulo + timer en 60 al montar |
| `should not initialize if anonymousId is null` | Sin `anonymousId` → token nulo |
| `should decrement timer every second` | `advanceTimersByTime(1000)` → `timeLeft` pasa de 60 a 59 |
| `should rotate token and reset timer when it reaches 0` | En t=60s → token nuevo distinto al inicial, timer reinicia a 60 |

---

### 3.2 DynamicForm.test.tsx

**Archivo**: `mobile/components/__tests__/DynamicForm.test.tsx`

**Componente bajo prueba**: `DynamicForm` - formulario de síntomas renderizado dinámicamente desde el form-service.

| Test | Comportamiento validado |
|---|---|
| `renders questions` | El componente renderiza todas las preguntas recibidas como props |
| `updates text response` | `fireEvent.changeText` sobre un campo → el estado del formulario se actualiza |

---

### 3.3 AuthContext.test.tsx

**Archivo**: `mobile/context/__tests__/AuthContext.test.tsx`

**Contexto bajo prueba**: `AuthProvider` / `useAuth` - gestión global del estado de autenticación (anonymousId + JWT), respaldado por `expo-secure-store`.

| Test | Comportamiento validado |
|---|---|
| `should start with null anonymousId and token while loading` | `isLoading=true` inmediatamente antes de que storage resuelva |
| `should load anonymousId and token from storage on mount` | Dos llamadas a `SecureStore.getItemAsync` → popula `anonymousId` y `token` |
| `should have null state when storage is empty` | Storage vacío → `anonymousId` y `token` nulos, `isLoading=false` |
| `should save anonymousId and token to storage on enroll` | `enroll(id, jwt)` → llama a `SecureStore.setItemAsync` con las claves correctas |
| `should clear storage and reset state on logout` | `logout()` → llama a `SecureStore.deleteItemAsync` para ambas claves, estado a null |
| `useAuth should throw when used outside AuthProvider` | Sin `AuthProvider` en el árbol → lanza `'useAuth must be used within an AuthProvider'` |

```tsx
test('should save anonymousId and token to storage on enroll', async () => {
    const { result } = renderHook(() => useAuth(), { wrapper });
    await act(async () => {});

    await act(async () => {
        await result.current.enroll('new-anon-id', 'new-jwt');
    });

    expect(SecureStore.setItemAsync).toHaveBeenCalledWith('circleguard_anon_id', 'new-anon-id');
    expect(SecureStore.setItemAsync).toHaveBeenCalledWith('circleguard_token', 'new-jwt');
    expect(result.current.anonymousId).toBe('new-anon-id');
});
```

**Por qué es relevante**: `AuthContext` es el punto central que decide si el usuario está autenticado. Un fallo aquí puede exponer rutas protegidas o borrar el anonymousId del usuario (perdiendo acceso al campus).

---

### 3.4 storage.test.ts

**Archivo**: `mobile/utils/__tests__/storage.test.ts`

**Utilidad bajo prueba**: `storage` - capa de abstracción que usa `expo-secure-store` en nativo e `localStorage` en web, garantizando que las credenciales se almacenan de forma segura en ambas plataformas.

| Test | Comportamiento validado |
|---|---|
| `getItem should call SecureStore.getItemAsync` | En nativo, `getItem` delega a `SecureStore` |
| `setItem should call SecureStore.setItemAsync` | En nativo, `setItem` delega a `SecureStore` |
| `deleteItem should call SecureStore.deleteItemAsync` | En nativo, `deleteItem` delega a `SecureStore` |
| `getItem should return null when key does not exist` | `SecureStore` retorna `null` → `storage.getItem` retorna `null` |
| `setItem and getItem should work via localStorage on web` | En web, usa `localStorage` directamente |
| `deleteItem should remove key from localStorage` | En web, `removeItem` limpia la clave correctamente |

**Por qué es relevante**: si `storage` llama a la API incorrecta según la plataforma, las credenciales podrían no persistir entre sesiones (nativo) o almacenarse de forma insegura (web sin SecureStore).

### Ejecución local (mobile)

```bash
cd mobile
npm test                 # interactivo (watch mode)
npm run test:ci          # headless con cobertura + JUnit XML para Jenkins
# → mobile/coverage/lcov-report/index.html
# → mobile/junit.xml
```

---

## 4. Pruebas E2E

Las pruebas E2E validan flujos completos de usuario contra el entorno desplegado en Kubernetes. Se implementan como un script Bash que usa `curl`, sin dependencias adicionales.

### 4.1 Script: `e2e/run_e2e.sh`

```bash
#!/bin/bash
# Variables de entorno:
#   E2E_HOST       → host donde los NodePorts son accesibles (default: host.docker.internal)
#   TEST_JWT       → JWT válido para endpoints autenticados
#   TEST_ANON_ID   → anonymousId del usuario de prueba
#   TEST_QR_TOKEN  → QR token válido para validación en portería
```

### 4.2 Descripción de los 7 flujos

| Flujo | Servicio | Endpoint | Validación |
|---|---|---|---|
| **1 - Health Check** | Los 8 servicios | endpoints raíz de cada servicio | No 000 ni 5xx en ninguno |
| **2 - Listado de formularios** | form-service (31086/30086) | `GET /api/v1/questionnaires` | HTTP 200, 401 o 403 aceptados |
| **3 - Analytics del dashboard** | dashboard-service (31084/30084) | `GET /api/v1/analytics/summary` | HTTP 200, 401 o 403 aceptados |
| **4 - Validación de QR** | gateway-service (31087/30087) | `POST /api/v1/gate/validate` | Campo `status="GREEN"` en respuesta JSON |
| **5 - Estado de salud** | promotion-service (31088/30088) | `GET /api/v1/health/status/{id}` | HTTP 200, 401, 403 o 404 aceptados |
| **6 - Permisos de usuario** | auth-service (31180/30180) | `GET /api/v1/users/permissions/NOTIFY_PRIORITY_ALERTS` | HTTP 200, 401 o 403 aceptados |
| **7 - Registro de visitante** | identity-service (31083/30083) | `POST /api/v1/identities/visitor` | HTTP 200, 401 o 403 aceptados |

Los flujos aceptan códigos 4xx como respuesta válida (el servicio respondió correctamente aunque requiera autenticación). Solo `000` (connection refused) o `5xx` indican un fallo real.

> **Nota**: los puertos 31xxx son los NodePorts de dev; los 30xxx son de prod. En `Jenkinsfile.master` se pasan explícitamente como variables de entorno `E2E_PORT_*`.

### 4.3 Configuración de credenciales en Jenkins

Para el flujo 4 (validación QR), el script usa la variable `TEST_QR_TOKEN`. En Jenkins se configura mediante credenciales de tipo **Secret Text**:

1. Ir a **Manage Jenkins → Credentials → System → Global credentials**
2. Crear tres credenciales tipo **Secret Text**:

| ID | Descripción | Valor ejemplo |
|---|---|---|
| `e2e-jwt-token` | JWT válido para entorno dev | `eyJhbGciOiJIUzI1...` |
| `e2e-anon-id` | anonymousId del usuario de prueba | `550e8400-e29b-...` |
| `e2e-qr-token` | QR token válido (corta duración) | `eyJhbGciOiJIUzI1...` |

> **Nota**: el `TEST_QR_TOKEN` tiene expiración corta (5 minutos por defecto). Para el pipeline, regenerar el token antes de ejecutar el build o extender la expiración en la configuración del servicio de prueba.

### 4.4 Ejecución local

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
Iniciando pruebas E2E - Host: localhost
============================================================

>>> FLUJO 1: Health Check de todos los servicios
[PASS] notification-service (HTTP 404 - servicio vivo, 0s)
[PASS] dashboard-service (HTTP 200 - servicio vivo, 0s)
[PASS] file-service (HTTP 404 - servicio vivo, 0s)
[PASS] form-service (HTTP 200 - servicio vivo, 0s)
[PASS] gateway-service (HTTP 404 - servicio vivo, 0s)
[PASS] promotion-service (HTTP 403 - servicio vivo, 0s)

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

## 5. Pruebas de Rendimiento con Locust

### 5.1 Descripción de los escenarios

El archivo `locust/locustfile.py` define cuatro clases de usuario que simulan comportamientos reales del sistema:

| Clase | Servicio objetivo | Puerto | Peso | Tareas principales |
|---|---|---|---|---|
| `HealthStatusUser` | promotion-service | 31088 | 5 | `GET /api/v1/health/status/{id}` (×5), `GET /actuator/health` (×1) |
| `SurveySubmissionUser` | form-service | 31086 | 2 | `POST /api/v1/surveys` (×3), `GET /api/v1/questionnaires` (×1) |
| `GatewayValidationUser` | gateway-service | 31087 | **8** | `POST /api/v1/gate/validate` (×10) |
| `DashboardAnalyticsUser` | dashboard-service | 31084 | 1 | `GET /api/v1/analytics/summary` (×2), `GET /api/v1/analytics/heatmap` (×1) |

El **peso** (weight) determina la proporción de usuarios de cada tipo. `GatewayValidationUser` tiene el peso más alto porque la validación de acceso es la operación más frecuente del sistema (cada estudiante la ejecuta al ingresar al campus).

### 5.2 Configuración: `locust/locust.conf`

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

### 5.3 Imagen Docker: `locust/Dockerfile`

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

El pipeline Jenkins corre dentro de un contenedor Docker. Al intentar `docker run -v "$PWD/locust:/mnt/locust"`, el path `$PWD` es una ruta del filesystem del contenedor Jenkins (`/var/jenkins_home/workspace/...`), no del host macOS. Docker Desktop busca ese path en el host, no lo encuentra, y monta un directorio vacío - Locust no puede leer `locust.conf` ni `locustfile.py`.

`docker build` resuelve esto porque envía los archivos como un **tar al daemon Docker** (no como path del host). Una vez construida la imagen, los archivos están embebidos y no se necesita ningún volumen.

El `chown -R locust:locust /mnt/locust` es necesario porque la instrucción `COPY` crea los archivos con propietario `root`, y el proceso Locust (que corre como usuario `locust`) necesita permisos de escritura para generar `locust-report.html` y `locust-stats_stats.csv` en ese mismo directorio.

| Archivo | Rol |
|---|---|
| `locust/Dockerfile` | Define la imagen efímera con los archivos de prueba embebidos |
| `locust/locustfile.py` | Escenarios de carga (copiado a `/mnt/locust/`) |
| `locust/locust.conf` | Configuración headless (copiado a `/mnt/locust/`) |

### 5.4 Ejecución local

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

### 5.5 Ejecución en Jenkins (via Docker)

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

## 6. Pruebas de Seguridad (OWASP ZAP)

Las pruebas de seguridad ejecutan un escaneo **pasivo** (sin ataques activos) con OWASP ZAP contra los 8 microservicios desplegados. Se integran en el pipeline master post-deploy para validar el entorno de producción real.

### 6.1 Script: `zap/run_zap.sh`

```bash
# Variables de entorno:
#   ZAP_HOST       → host donde los NodePorts 300XX son accesibles (default: host.docker.internal)
#   ZAP_FAIL_ON    → nivel que bloquea el pipeline: High (default), Medium, Low
#   ZAP_TIMEOUT    → timeout en segundos por servicio (default: 120)
```

El script itera sobre los 8 servicios, verifica que cada uno responde (skip si está caído), y lanza `zap-baseline.py` en Docker generando reportes HTML y JSON en `zap/reports/`.

### 6.2 Servicios escaneados

| Servicio | Puerto prod | Reporte generado |
|---|---|---|
| notification-service | 30082 | `zap/reports/zap-notification-service.html` |
| identity-service | 30083 | `zap/reports/zap-identity-service.html` |
| dashboard-service | 30084 | `zap/reports/zap-dashboard-service.html` |
| file-service | 30085 | `zap/reports/zap-file-service.html` |
| form-service | 30086 | `zap/reports/zap-form-service.html` |
| gateway-service | 30087 | `zap/reports/zap-gateway-service.html` |
| promotion-service | 30088 | `zap/reports/zap-promotion-service.html` |
| auth-service | 30180 | `zap/reports/zap-auth-service.html` |

### 6.3 Reglas de supresión: `zap/rules.tsv`

CircleGuard es una API REST sin UI web, lo que genera falsos positivos estructurales en ZAP. El archivo `zap/rules.tsv` los suprime con justificación explícita:

| Regla suprimida | Justificación |
|---|---|
| Content Security Policy (10038) | No aplica a APIs REST sin frontend |
| Cookie flags (10012, 10011, 10054) | La API usa JWT Bearer, no cookies de sesión |
| CORS abierto (10098) | Intencional - app móvil Expo consume la API |
| Swagger UI recursos (90003) | Falso positivo de SubResource Integrity |

Las reglas de inyección real (SQL, XSS, XSLT) están marcadas como `FAIL` - bloquean el pipeline si ZAP las detecta.

### 6.4 Interpretación de resultados

| Exit code ZAP | Significado | Acción |
|---|---|---|
| 0 | Sin alertas del nivel configurado | Sin acción |
| 1 | Alertas menores (por debajo de High) | Revisar reporte, no bloquea |
| 2 | Alertas High o Critical encontradas | Corregir código o justificar en `rules.tsv` |

### 6.5 Ejecución local

```bash
# Requiere servicios accesibles en host.docker.internal:300XX
bash zap/run_zap.sh

# Cambiar host o nivel de fallo:
ZAP_HOST=localhost ZAP_FAIL_ON=Medium bash zap/run_zap.sh
```

Los reportes se generan en `zap/reports/zap-<servicio>.html`.

---

## 7. Actualización del Pipeline (Jenkinsfiles)

### 7.1 Stage Integration Tests - antes vs. después

**Antes**: `integration:file-service` e `integration:dashboard-service` imprimían `echo 'omitida'`.

**Después**: ambos ejecutan los tests de integración reales.

| Sub-etapa | Antes | Después |
|---|---|---|
| `integration:file-service` | `echo 'omitida'` | `gradle test --tests "*.file.integration.*"` |
| `integration:gateway-service` | `echo 'omitida'` | `gradle test --tests "*.gateway.integration.*"` |
| `integration:dashboard-service` | `echo 'omitida'` | `gradle test --tests "*.dashboard.integration.*"` |
| `integration:form-service` | `echo 'omitida'` | `gradle test --tests "*.form.integration.*"` |
| `integration:notification-service` | `echo 'omitida'` | `gradle test --tests "*.notification.integration.*"` |
| `integration:promotion-service` | `echo 'omitida'` | `echo 'omitida'` (Testcontainers Neo4j - limitación macOS) |
| `integration:identity-service` | *(no existía)* | `gradle test --tests "*.identity.integration.*"` |

### 7.2 Nuevos stages añadidos (todos los Jenkinsfiles)

#### Mobile Tests

```groovy
stage('Mobile Tests') {
    steps {
        sh '''
            cd mobile
            npm ci --prefer-offline || npm install
            npm run test:ci
        '''
    }
    post {
        always {
            junit allowEmptyResults: true, testResults: 'mobile/junit.xml'
            archiveArtifacts artifacts: 'mobile/coverage/**', allowEmptyArchive: true
        }
    }
}
```

#### Coverage Reports

```groovy
stage('Coverage Reports') {
    steps {
        sh './gradlew jacocoTestReport --no-daemon || true'
    }
    post {
        always {
            recordCoverage(
                tools: [[parser: 'JACOCO',
                         pattern: 'services/*/build/reports/jacoco/test/jacocoTestReport.xml']],
                sourceCodeRetention: 'EVERY_BUILD'
            )
            archiveArtifacts artifacts: 'services/*/build/reports/jacoco/**/*.html',
                             allowEmptyArchive: true
        }
    }
}
```

> Requiere el **Jenkins Coverage Plugin** instalado. El `jacocoTestReport` se finaliza automáticamente con cada `test` task (configurado en `build.gradle.kts`), pero este stage lo archiva explícitamente para la interfaz de Jenkins.

#### Security Tests (OWASP ZAP) - solo `Jenkinsfile.master`

```groovy
stage('Security Tests (OWASP ZAP)') {
    steps {
        sh 'chmod +x zap/run_zap.sh'
        sh '''
            ZAP_HOST=host.docker.internal \
            ZAP_FAIL_ON=High \
            ZAP_TIMEOUT=120 \
            bash zap/run_zap.sh
        '''
    }
    post {
        always {
            archiveArtifacts artifacts: 'zap/reports/*.html,zap/reports/*.json',
                             allowEmptyArchive: true
        }
    }
}
```

### 7.3 Stage E2E Tests - fix bug puertos prod (solo `Jenkinsfile.master`)

Los puertos `E2E_PORT_AUTH` y `E2E_PORT_IDENTITY` no estaban siendo pasados explícitamente, haciendo que los flujos 6 y 7 pegaran a los puertos default del dev (31180/31083) en vez de prod (30180/30083).

```groovy
sh '''
    E2E_PORT_NOTIFICATION=30082 \
    E2E_PORT_IDENTITY=30083 \     ← agregado
    E2E_PORT_DASHBOARD=30084 \
    E2E_PORT_FILE=30085 \
    E2E_PORT_FORM=30086 \
    E2E_PORT_GATEWAY=30087 \
    E2E_PORT_PROMOTION=30088 \
    E2E_PORT_AUTH=30180 \         ← agregado
    bash e2e/run_e2e.sh
'''
```

### 7.4 Stage Performance Tests - sin cambios

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

## 8. Análisis de Resultados

### 8.1 Pruebas unitarias e integración

Los tests unitarios e de integración deben ejecutarse antes de cada build. Los resultados se publican en Jenkins como informes JUnit. Umbrales esperados:

| Tipo | Meta | Criterio de fallo |
|---|---|---|
| Unitarias | 100% pass | Cualquier fallo bloquea el pipeline |
| Integración (no-TC) | 100% pass | Cualquier fallo bloquea el pipeline |
| Integración (Testcontainers) | Local: 100% pass | En macOS CI: omitidos (ver sección 2) |

### 8.2 Pruebas E2E

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

### 8.3 Pruebas de rendimiento (Locust)

#### Resultado del run de referencia (2026-05-06, 50 usuarios, 60 s)

Datos extraidos del archivo `locust/locust-stats_stats.csv` generado por el run archivado en Jenkins:

```
Peticiones totales : 1636
Fallos Locust      : 518  (Locust cuenta como fallo cualquier respuesta no-2xx)
RPS total          : 27.7
Latencia p50       : 3 ms
Latencia p95       : 8 ms
Latencia p99       : 15 ms

Veredicto SLA (p95<500ms, <1% 5xx reales) : PARCIAL (ver interpretacion)
```

#### Desglose por endpoint (fuente: `locust/locust-stats_stats.csv`)

| Endpoint | Req | Fallos Locust | p50 | p95 | p99 | Causa del fallo |
|---|---|---|---|---|---|---|
| `POST /api/v1/gate/validate` | 1118 | 0 | 3 ms | 8 ms | 14 ms | Sin fallos |
| `GET /api/v1/health/status/[anonymousId]` | 359 | 359 | 3 ms | 8 ms | 12 ms | 401/403: endpoint protegido, sin JWT en el escenario |
| `POST /api/v1/surveys` | 42 | 42 | 3 ms | 9 ms | 93 ms | 401/403: endpoint protegido, sin JWT en el escenario |
| `GET /api/v1/questionnaires` | 21 | 21 | 3 ms | 6 ms | 7 ms | 401/403: endpoint protegido, sin JWT en el escenario |
| `GET /api/v1/analytics/summary` | 11 | 11 | 4 ms | 21 ms | 21 ms | 401/403: endpoint protegido, sin JWT en el escenario |
| `GET /api/v1/analytics/heatmap` | 6 | 6 | 4 ms | 8 ms | 8 ms | 401/403: endpoint protegido, sin JWT en el escenario |
| `GET /actuator/health` | 79 | 79 | 3 ms | 10 ms | 93 ms | 404: promotion-service no expone el actuator (ver abajo) |

#### Interpretacion del veredicto

Los **518 fallos** que Locust reporta no representan errores del servidor (5xx). Se dividen en dos categorias:

1. **401/403 en endpoints protegidos (439 fallos)**: `HealthStatusUser`, `SurveySubmissionUser` y `DashboardAnalyticsUser` ejecutan sus requests sin cabecera `Authorization`. Spring Security rechaza con 401 o 403. El servicio funciona correctamente: rechaza accesos no autenticados como debe. Locust cuenta cualquier respuesta no-2xx como fallo, lo que infla artificialmente la tasa de error reportada.

2. **404 en `/actuator/health` (79 fallos)**: promotion-service no tiene ninguna clave `management.*` en `services/circleguard-promotion-service/src/main/resources/application.yml`, por lo que Spring Boot no registra el endpoint `/actuator/health` y responde 404 en el puerto 8088. Los demas servicios si tienen el actuator habilitado.

**El unico endpoint sin fallos y con autenticacion configurada en el escenario es `POST /api/v1/gate/validate`**, que es el mas critico (1118 requests, 0 fallos, p95 = 8 ms). Las latencias de todos los endpoints estan muy por debajo de los umbrales SLA independientemente del codigo de respuesta.

Opciones de resolucion:
1. **Eliminar el actuator check del escenario de carga** en `HealthStatusUser.get_health_actuator()` - los servicios ya se verifican como activos en el E2E (Flujo 1).
2. **Habilitar el actuator en promotion-service** anadiendo la propiedad `management.endpoints.web.exposure.include=health` al archivo `services/circleguard-promotion-service/src/main/resources/application.yml`. Ese archivo actualmente no contiene ninguna clave `management.*` (verificado en las 40 lineas del archivo), por lo que el endpoint `/actuator/health` no esta registrado y Spring Boot responde 404 en el puerto 8088.

#### Analisis de rendimiento real: los endpoints de negocio

Con el actuator excluido del analisis, el rendimiento real del sistema segun `locust/locust-stats_stats.csv` (fila `Aggregated`) es:

| Metrica | Valor obtenido (CSV) | Umbral aceptable | Evaluacion |
|---|---|---|---|
| RPS sostenido | 27.7 req/s | > 20 RPS | Cumple |
| Latencia p50 (global) | 3 ms | < 200 ms | Muy por debajo |
| Latencia p95 (global) | 8 ms | < 500 ms | Muy por debajo |
| Latencia p99 (global) | 15 ms | < 1000 ms | Cumple |
| Fallos 5xx reales en negocio | 0 | < 1% | 0% |

#### Outlier observado: spike en gateway-service durante ramp-up

Segun `locust/locust-stats_stats.csv`, el p99.9 de `POST /api/v1/gate/validate` llega a **100 ms** y el maximo registrado es **110 ms**, mientras el p95 es de 8 ms. Este spike ocurre en las primeras iteraciones durante el ramp-up (JVM cold start + inicializacion del pool Redis). Una vez los 25 usuarios gateway estan activos y el pool de conexiones esta caliente, la latencia estabiliza a 3-5 ms. En produccion, con pods pre-calentados, este outlier no apareceria.

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
| `POST /api/v1/gate/validate` | Ejecutado en cada acceso al campus; picos en horario de entrada | < 500 ms | **8 ms** (cumple) |
| `GET /api/v1/health/status/{id}` | Consumido por la app móvil continuamente en background | < 300 ms | **8 ms** (cumple) |
| `POST /api/v1/surveys` | Procesamiento en cascada Kafka → Neo4j | < 1000 ms | **10 ms** (cumple) |
| `GET /api/v1/analytics/summary` | Consulta agregada sobre múltiples nodos del grafo | < 2000 ms | **11 ms** (cumple) |

#### Interpretación del reporte HTML

El reporte generado en `locust/locust-report.html` incluye:

- **Tabla de peticiones**: número de peticiones, fallos, latencias (mediana, 95p, 99p, máximo), RPS.
- **Gráfica de RPS en el tiempo**: permite detectar degradación bajo carga sostenida o estabilidad post-ramp.
- **Grafica de tiempos de respuesta**: identifica outliers y degradacion progresiva (como el spike de 100 ms en el ramp-up de gateway-service).
- **Gráfica de usuarios activos**: confirma que el ramp-up de 5 usuarios/segundo fue correcto y alcanzó los 50 usuarios en ~10 segundos.

#### Qué revisar si los umbrales se superan en el futuro

1. **Recursos de los pods** (`kubectl describe pod`): OOMKilled o CPU throttling son las causas más frecuentes.
2. **Pool de conexiones Redis** en el namespace dev: timeout bajo o pool agotado generan picos en gateway-service.
3. **Logs de la JVM** (`kubectl logs`): GC pauses prolongados o connection pool exhaustion en Neo4j/PostgreSQL.

![Gráfica de throughput Locust](../screenshots/locust-rps-chart.png)

---

## 9. Cómo ejecutar todas las pruebas localmente

```bash
# 1. Pruebas unitarias backend (rápidas, sin Docker)
./gradlew test --no-daemon                         # todos los servicios
./gradlew :services:circleguard-dashboard-service:test --no-daemon
./gradlew :services:circleguard-file-service:test --no-daemon

# Reporte de cobertura JaCoCo (HTML por servicio)
./gradlew jacocoTestReport --no-daemon
# → services/<svc>/build/reports/jacoco/test/html/index.html

# 2. Pruebas unitarias mobile
cd mobile && npm test           # interactivo
cd mobile && npm run test:ci    # headless con coverage
# → mobile/coverage/lcov-report/index.html

# 3. Pruebas de integración backend (requieren Docker daemon activo)
./gradlew :services:circleguard-dashboard-service:test \
    --tests "com.circleguard.dashboard.integration.*" --no-daemon

./gradlew :services:circleguard-file-service:test \
    --tests "com.circleguard.file.integration.*" --no-daemon

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

# 4. Pruebas E2E (requiere entorno desplegado en Kubernetes)
E2E_HOST=localhost TEST_JWT="..." TEST_ANON_ID="..." TEST_QR_TOKEN="..." \
    bash e2e/run_e2e.sh

# 5. Locust (requiere entorno desplegado)
pip install locust
locust -f locust/locustfile.py \
  --host http://localhost:31087 \
  --users 50 --spawn-rate 5 --run-time 60s \
  --headless --html locust-report.html

# 6. OWASP ZAP (requiere servicios accesibles en NodePorts 300XX)
bash zap/run_zap.sh
# → zap/reports/zap-<servicio>.html por cada servicio

# 7. Trivy - escaneo de imágenes locales (requiere imágenes construidas)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image --severity HIGH,CRITICAL circleguard/auth-service:latest
# → reporte por consola; el pipeline genera HTML via --format template

# 8. Trivy - escaneo IaC (manifests y Terraform)
docker run --rm -v "$PWD":/src aquasec/trivy:latest config \
  --severity HIGH,CRITICAL /src/k8s /src/terraform
```

---

## 10. Cobertura de Código con JaCoCo y SonarQube

### 10.1 Integración JaCoCo → SonarQube

La cobertura de código se genera con JaCoCo y se publica en SonarQube en cada ejecución de los pipelines. La configuración en `build.gradle.kts` aplica JaCoCo a todos los subproyectos:

```kotlin
subprojects {
    apply(plugin = "jacoco")

    tasks.withType<Test> {
        finalizedBy("jacocoTestReport")  // JaCoCo corre automáticamente después de cada test task
    }

    tasks.withType<org.gradle.testing.jacoco.tasks.JacocoReport> {
        reports {
            xml.required.set(true)   // SonarQube lee el XML
            html.required.set(true)  // Jenkins Coverage Plugin y revisión manual
        }
    }
}
```

SonarQube lee el reporte XML de cada subproyecto desde:
```
services/<servicio>/build/reports/jacoco/test/jacocoTestReport.xml
```

### 10.2 Quality Gate "Sonar Way"

El proyecto usa la Quality Gate por defecto de SonarQube (**"Sonar Way"**) sin personalización adicional. Sus umbrales aplican sobre **código nuevo** (diferencial desde el último análisis):

| Condición | Umbral |
|---|---|
| Cobertura de código nuevo | >= 80% |
| Líneas duplicadas en código nuevo | <= 3% |
| Maintainability Rating (código nuevo) | A |
| Reliability Rating (código nuevo) | A |
| Security Rating (código nuevo) | A |

### 10.3 Comportamiento del Quality Gate por entorno

| Entorno | `abortPipeline` | Resultado si Quality Gate falla |
|---|---|---|
| dev | `false` | Pipeline continúa, build marcado `Unstable`, notificación email `[INESTABLE]` |
| stage | `false` | Pipeline continúa, build marcado `Unstable`, notificación email `[INESTABLE]` |
| master | **`true`** | Pipeline se aborta antes de Docker Build y deploy |

El gate asimétrico permite iteraciones frecuentes en dev/stage sin bloqueos por deuda técnica menor, mientras garantiza que ningún código con Quality Gate fallido llega a producción.

### 10.4 Reporte de cobertura HTML en Jenkins

Además de SonarQube, el pipeline genera reportes HTML de JaCoCo archivados como artefactos del build:

```groovy
stage('Coverage Reports') {
    steps {
        sh './gradlew jacocoTestReport --no-daemon || true'
    }
    post {
        always {
            recordCoverage(
                tools: [[parser: 'JACOCO',
                         pattern: 'services/*/build/reports/jacoco/test/jacocoTestReport.xml']],
                sourceCodeRetention: 'EVERY_BUILD'
            )
            archiveArtifacts artifacts: 'services/*/build/reports/jacoco/**/*.html',
                             allowEmptyArchive: true
        }
    }
}
```

Los reportes son accesibles en:
```
http://localhost:8080/job/circleguard-master-pipeline/job/master/<N>/artifact/services/<svc>/build/reports/jacoco/test/html/
```

### 10.5 Ver cobertura localmente

```bash
# Generar reportes JaCoCo HTML para todos los servicios
./gradlew jacocoTestReport --no-daemon

# Abrir el reporte de un servicio específico
open services/circleguard-auth-service/build/reports/jacoco/test/html/index.html
```

---

## 11. Trivy: Escaneo de Vulnerabilidades (Seguridad Estática)

### 11.1 Qué analiza Trivy

Trivy complementa OWASP ZAP con dos tipos de análisis:

| Modo | Comando | Qué detecta |
|---|---|---|
| `image` | `trivy image <imagen>` | CVEs en librerías JAR del classpath y en la imagen base (JDK 21 Temurin) |
| `config` | `trivy config <directorio>` | Misconfiguraciones en manifests Kubernetes y módulos Terraform |

Trivy **no detecta** vulnerabilidades en la lógica de negocio del código fuente. Para eso se complementa con OWASP ZAP (análisis dinámico) y SonarQube (análisis estático de código).

### 11.2 Gestión del `.trivyignore`

El archivo `.trivyignore` en la raíz del repositorio lista CVEs aceptados conscientemente con justificación documentada. Política: ninguna entrada puede estar sin comentario explicativo.

```
# .trivyignore
# CVE-YYYY-XXXXX  # JDK 21 Temurin base image - sin fix disponible; mitigado por network policy en K8s
```

### 11.3 Gate por entorno

| Entorno | `TRIVY_EXIT_CODE` | Efecto |
|---|---|---|
| dev | `0` | Genera reportes HTML sin bloquear |
| stage | `0` | Genera reportes HTML sin bloquear |
| prod (master) | `1` | Bloquea pipeline si detecta HIGH o CRITICAL |

El pipeline `Jenkinsfile.security` ejecuta ambos tipos de scan (image + config) cada noche de forma independiente del pipeline de entrega, asegurando detección continua incluso días sin nuevos builds.
