# Informe Final — CircleGuard

## Tabla de Contenidos

1. [Metodología Ágil y Estrategia de Branching](#1-metodología-ágil-y-estrategia-de-branching)
2. [Configuración de Jenkins, Docker y Kubernetes](#2-configuración-de-jenkins-docker-y-kubernetes)
3. [Patrones de Diseño](#3-patrones-de-diseño)
4. [Pipeline de Desarrollo (Dev)](#4-pipeline-de-desarrollo-dev)
5. [Pruebas Completas](#5-pruebas-completas)
6. [Pipeline de Stage](#6-pipeline-de-stage)
7. [Pipeline de Producción (Master)](#7-pipeline-de-producción-master)
8. [CI/CD Avanzado](#8-cicd-avanzado)
9. [Change Management y Release Notes](#9-change-management-y-release-notes)
10. [Observabilidad y Monitoreo](#10-observabilidad-y-monitoreo)
11. [Seguridad](#11-seguridad)
12. [Costos de Infraestructura](#12-costos-de-infraestructura)
13. [Manual de Operaciones](#13-manual-de-operaciones)

---

# 1. Metodología Ágil y Estrategia de Branching

## 1.1 Metodología Scrum

Se adoptó Scrum como marco de trabajo ágil dado que el proyecto presenta alta complejidad técnica, múltiples componentes interdependientes (8 microservicios, infraestructura Kubernetes, pipelines CI/CD, observabilidad y seguridad) y la necesidad de validación incremental del avance. Scrum permite organizar el trabajo en iteraciones cortas (sprints), facilita la detección temprana de impedimentos y promueve la entrega continua de valor medible en cada iteración.

### Equipo Scrum

El proyecto es desarrollado por un equipo de **2 integrantes**. Los roles rotan entre sprints:

| Rol | Sprint 1 | Sprint 2 |
| ----- | ----- | ----- |
| **Product Owner** | Integrante A | Integrante B |
| **Scrum Master** | Integrante B | Integrante A |
| **Development Team** | Ambos integrantes | Ambos integrantes |

**Product Owner**: prioriza el backlog, valida criterios de aceptación al cierre de cada historia y representa los intereses del proyecto en las revisiones de sprint.

**Scrum Master**: facilita ceremonias, remueve impedimentos técnicos y organizativos, y vela por el cumplimiento del proceso Scrum.

**Development Team**: implementa, estima, diseña técnicamente, revisa código y documenta en los dos sprints.

### Estructura de cada sprint

| Ceremonia | Momento | Duración máx. | Propósito |
| ----- | ----- | ----- | ----- |
| **Sprint Planning** | Inicio del sprint (día 1) | 2 horas | Seleccionar historias y definir Sprint Goal |
| **Daily Scrum** | Cada día laborable | 15 minutos | Sincronización y bloqueos |
| **Sprint Review** | Final del sprint (día 14) | 1 hora | Demostrar incremento, obtener feedback |
| **Sprint Retrospective** | Después de la Review | 45 minutos | Mejoras al proceso |

### Definition of Done (DoD)

Una historia se considera completada únicamente cuando cumple todos los siguientes criterios:

- El código compila sin errores en todos los módulos afectados.
- Tests unitarios pasan al 100% para las clases modificadas.
- Tests de integración pasan para los servicios involucrados.
- SonarQube Quality Gate en estado `OK` o `WARN` con ticket de deuda técnica creado.
- PR revisado con al menos un comentario de revisión técnica.
- La funcionalidad fue demostrada funcionando en el entorno dev (namespace `circleguard-dev`).
- La documentación correspondiente fue actualizada o creada.
- Los criterios de aceptación de la historia fueron verificados manualmente.

## 1.2 Backlog del Proyecto

El backlog se organizó en **8 épicas**, cada una correspondiente a un componente evaluable. En total se definieron **23 historias de usuario**, distribuidas en 2 sprints de 2 semanas cada uno.

| Épica | Componente | Sprint |
| ----- | ----- | ----- |
| EP-01 | Metodología Ágil y Branching | 1 |
| EP-02 | Infraestructura como Código (Terraform) | 1 |
| EP-03 | Configuración Jenkins, Docker y Kubernetes | 1 |
| EP-04 | Pipeline Dev y Stage | 1 |
| EP-05 | Pruebas Completas | 1 + 2 |
| EP-06 | Patrones de Diseño | 2 |
| EP-07 | CI/CD Avanzado y Change Management | 2 |
| EP-08 | Observabilidad, Seguridad y Documentación | 2 |

### Sprint 1: "Fundación e Infraestructura"

**Sprint Goal**: Establecer las bases técnicas: repositorio con GitFlow, infraestructura en Kubernetes con todos los microservicios operativos, y pipelines CI/CD para dev y stage.

**Velocity**: 62 puntos entregados de 62 planificados (100%).

Impedimentos encontrados y resueltos:
- Testcontainers Java incompatible con Docker Desktop socket proxy en macOS → tests Testcontainers de `promotion-service` marcados como omitidos en CI.
- kubeconfig apunta a `127.0.0.1:6443` que desde el contenedor Jenkins no es el host → copia parcheada con `host.docker.internal:6443` persistida en el volumen `jenkins_home`.
- `kubectl rollout status` retorna éxito antes de que Spring Boot inicie → se añadió `readinessProbe` a todos los manifests.

### Sprint 2: "Calidad, Seguridad y Observabilidad"

**Sprint Goal**: Completar calidad (SonarQube, Trivy, ZAP), visibilidad (Prometheus, Grafana, ELK, Zipkin), seguridad (RBAC, TLS, secretos) y documentación formal.

**Velocity**: 55 puntos entregados de 55 planificados (100%).

## 1.3 Estrategia de Branching: GitFlow

Se adopta GitFlow dado que el proyecto exige tres ambientes diferenciados (dev, stage, prod), un proceso formal de releases y planes de rollback documentados.

### Descripción de ramas

| Rama | Ambiente | Propósito | Reglas de protección |
| ----- | ----- | ----- | ----- |
| `main` | Producción | Código estable en producción | PR aprobado + pipeline master exitoso + gate manual Jenkins |
| `develop` | Desarrollo | Integración continua de features | PR aprobado + pipeline dev exitoso |
| `release/*` | Staging | Preparación y validación de versiones | PR aprobado, solo bugfixes permitidos |
| `feature/*` | Local / dev | Desarrollo de historias del backlog | Sin restricción; rama siempre desde `develop` |
| `hotfix/*` | - | Correcciones urgentes sobre producción | PR aprobado; merge a `main` y `develop` simultáneamente |

### Convención de commits (Conventional Commits)

| Prefijo | Significado | Bump semver |
| ----- | ----- | ----- |
| `feat:` | Nueva funcionalidad | MINOR |
| `fix:` | Corrección de bug | PATCH |
| `docs:` | Solo documentación | PATCH |
| `test:` | Adición de pruebas | PATCH |
| `ci:` | Cambios en pipelines | PATCH |
| `chore:` | Mantenimiento | PATCH |
| `feat!:` / `BREAKING CHANGE` | Cambio incompatible | MAJOR |

## 1.4 Gestión del Proyecto con Jira

Se utilizó Jira Software configurado como proyecto Scrum. La jerarquía de issues es: **Épica → Historia → Sub-tarea → Bug**.

| Parámetro | Configuración |
| ----- | ----- |
| Tipo de proyecto | Software (Scrum) |
| Prefijo de issues | CG |
| Sprints | 2 sprints de 2 semanas |
| Estimación | Story points (Fibonacci) |
| Columnas del board | To Do → In Progress → In Review → Done |

Los commits del repositorio incluyen referencia `Closes CG-XX` en el pie del mensaje para cerrar la trazabilidad entre commit → historia de usuario.

---

# 2. Configuración de Jenkins, Docker y Kubernetes

## 2.1 Resumen

La configuración del entorno de desarrollo incluye:

- **Jenkins**: servidor CI/CD standalone en Docker, fuera del clúster Kubernetes.
- **Docker**: containerización multi-stage de los 8 microservicios.
- **Kubernetes**: clúster Docker Desktop con namespace `circleguard` para producción.

Los 8 microservicios del proyecto son:

| Servicio | Puerto | Dependencias clave |
|---|---|---|
| `circleguard-file-service` | 8085 | Ninguna |
| `circleguard-gateway-service` | 8087 | Redis, JWT |
| `circleguard-dashboard-service` | 8084 | PostgreSQL |
| `circleguard-form-service` | 8086 | PostgreSQL, Kafka |
| `circleguard-notification-service` | 8082 | Kafka, SMTP |
| `circleguard-promotion-service` | 8088 | PostgreSQL, Neo4j, Redis, Kafka |
| `circleguard-auth-service` | 8180 | PostgreSQL, OpenLDAP, JWT |
| `circleguard-identity-service` | 8083 | PostgreSQL |

## 2.2 Configuración de Jenkins

Jenkins se ejecuta como contenedor Docker usando una imagen personalizada (`jenkins/Dockerfile`) que instala `docker` y `kubectl` sobre `jenkins/jenkins:lts`.

**Comando de arranque:**

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add 0 \
  --add-host=kubernetes.docker.internal:host-gateway \
  -v ~/.kube/config:/var/jenkins_home/.kube/config:ro \
  -v ~/.gradle:/var/jenkins_home/.gradle \
  circleguard/jenkins:latest
```

| Volumen / flag | Propósito |
|---|---|
| `jenkins_home` | Persistencia de configuración, jobs y plugins |
| `/var/run/docker.sock` | Acceso al Docker daemon del host |
| `--group-add 0` | Agrega al usuario `jenkins` el GID 0 (requerido por Docker Desktop Mac) |
| `--add-host=kubernetes.docker.internal:host-gateway` | Resuelve el API server Kubernetes desde el contenedor |
| `~/.gradle` | Cache de Gradle del host; evita descargar el wrapper en cada build |

**Kubeconfig parcheado**: el kubeconfig montado apunta a `127.0.0.1:6443`. Se crea una copia parcheada con `host.docker.internal:6443` persistida en `jenkins_home` y referenciada por `KUBECONFIG=/var/jenkins_home/kube-jenkins.conf` en todos los pipelines.

**Plugins adicionales requeridos**: Docker Pipeline, Kubernetes CLI, SonarQube Scanner, Email Extension, Coverage Plugin.

## 2.3 Dockerfiles — Estrategia Multi-Stage

Cada microservicio tiene su `Dockerfile` en `services/<nombre>/Dockerfile`. Todos siguen el mismo patrón de dos etapas:

**Etapa 1 - builder** (`eclipse-temurin:21-jdk-alpine`): compila el JAR ejecutable con Gradle.

**Etapa 2 - runtime** (`eclipse-temurin:21-jre-alpine`): imagen final mínima (~200 MB) que copia únicamente el JAR. Ejecuta como usuario no-root (`appuser`, UID 1001) por seguridad y compatibilidad con `runAsNonRoot: true` en Kubernetes.

El **contexto de build siempre es la raíz del repositorio** porque `settings.gradle.kts` y `build.gradle.kts` residen ahí y Gradle debe ver todos los módulos del monorepo.

## 2.4 Kubernetes — Estructura de Manifests

Los manifests están organizados en `k8s/`:

```
k8s/
├── 00-namespace.yml              # Namespace "circleguard"
├── infra/
│   ├── 01-configmap.yml          # Variables de entorno no-secretas
│   ├── 02-secrets.yml            # Contraseñas y claves (base64)
│   ├── 03-postgres.yml           # PostgreSQL 16
│   ├── 04-neo4j.yml              # Neo4j 5.26 con plugin APOC
│   ├── 05-zookeeper.yml
│   ├── 06-kafka.yml              # Apache Kafka 7.6
│   ├── 07-redis.yml              # Redis 7.2
│   ├── 08-mailhog.yml            # MailHog (SMTP desarrollo)
│   ├── 09-openldap.yml           # OpenLDAP
│   ├── 10-prometheus.yml         # Prometheus + reglas de alerta
│   ├── 11-alertmanager.yml       # Alertmanager → MailHog
│   ├── 12-elasticsearch.yml      # Elasticsearch single-node
│   ├── 13-logstash.yml           # Logstash (beats → ES)
│   ├── 14-kibana.yml             # Kibana UI
│   ├── 15-filebeat.yml           # Filebeat DaemonSet + RBAC
│   ├── 16-zipkin.yml             # Zipkin tracing
│   ├── 17-grafana.yml            # Grafana + dashboards
│   ├── 18-rbac.yml               # ServiceAccounts, Roles, RoleBindings
│   └── 19-ingress.yml            # ingress-nginx + TLS cert
└── services/
    ├── 09-file-service.yml
    ├── 10-gateway-service.yml
    ├── 11-dashboard-service.yml
    ├── 12-form-service.yml
    ├── 13-notification-service.yml
    ├── 14-promotion-service.yml
    ├── 15-auth-service.yml
    └── 16-identity-service.yml
```

---

# 3. Patrones de Diseño

## 3.1 Patrones Existentes en la Arquitectura

| Patrón | Categoría | Evidencia |
|---|---|---|
| **Builder** (Lombok `@Builder`) | Creacional | `identity-service/.../model/IdentityMapping.java`, `promotion-service/.../service/HealthStatusService.java` |
| **Factory** (Spring `@Bean`) | Creacional | `auth-service/.../config/SecurityConfig.java`, `promotion-service/.../config/CacheConfig.java` |
| **Adapter** (clientes HTTP) | Estructural | `auth-service/.../client/IdentityClient.java`, `dashboard-service/.../client/PromotionClient.java` |
| **Facade** | Estructural | `notification-service/.../service/NotificationDispatcher.java` — oculta Email/SMS/Push detrás de `dispatch()` |
| **Chain of Responsibility** | Comportamiento | `auth-service/.../security/DualChainAuthenticationProvider.java` — LDAP → Local DB |
| **Strategy** | Comportamiento | `notification-service/.../service/TemplateService.java`; interfaces `EmailService`/`SmsService`/`PushService` + `*Impl` |
| **Observer / Pub-Sub** (Kafka) | Comportamiento | Producers en `HealthStatusService`, listeners `SurveyListener`, `ExposureNotificationListener` |
| **State** | Comportamiento | `promotion-service/.../service/HealthStatusService.java` — transiciones `ACTIVE→SUSPECT→PROBABLE→CONFIRMED→RECOVERED` |
| **Template Method** | Comportamiento | Interfaces Spring Data `*Repository.java` |
| **Repository** | Arquitectural | `IdentityMappingRepository`, `LocalUserRepository`, repos Neo4j + JPA en promotion-service |
| **DTO** | Arquitectural | `promotion-service/.../dto/{Building,AccessPoint,Floor}DTO.java` |
| **Dependency Injection** | Arquitectural | Pervasivo vía `@RequiredArgsConstructor` en Lombok |
| **Retry** (Spring Retry) | Resiliencia | `notification-service/.../service/PushServiceImpl.java` |
| **Cache-Aside** (parcial existente) | Performance | `promotion-service/.../config/CacheConfig.java` — Caffeine + `@Cacheable/@CacheEvict` |
| **Scheduled Tasks** | Operacional | `StatusLifecycleService.java` — `@Scheduled` para transiciones automáticas |

## 3.2 Patrones Nuevos Implementados

### Circuit Breaker + Retry (Resiliencia)

**Objetivo**: proteger `auth-service` y `dashboard-service` de fallos en cascada cuando `identity-service` o `promotion-service` no están disponibles.

Se implementó con Resilience4j (`resilience4j-spring-boot3:2.2.0`) usando anotaciones `@CircuitBreaker` + `@Retry` sobre los métodos públicos de `IdentityClient` y `PromotionClient`.

**Configuración (auth-service/application.yml):**

```yaml
resilience4j:
  circuitbreaker:
    instances:
      identity:
        slidingWindowSize: 10
        failureRateThreshold: 50
        waitDurationInOpenState: 30s
        permittedNumberOfCallsInHalfOpenState: 3
  retry:
    instances:
      identity:
        maxAttempts: 3
        waitDuration: 500ms
```

La ventana deslizante de 10 llamadas es el mínimo estadísticamente estable para un threshold del 50%: necesita al menos 5 fallos reales para abrir el circuito, evitando falsos positivos con menos tráfico.

**ADR-0001**: Se eligió Resilience4j sobre Hystrix (deprecated 2018), Spring Retry solo (sin estado de CB), Feign (requiere Spring Cloud) e Istio/service mesh (requiere sidecar por pod, ~50 MB RAM extra por servicio = ~400 MB adicionales para 8 servicios en cluster con 4 GB).

**Test**: `./gradlew :services:circleguard-auth-service:test --tests "*IdentityClientResilienceTest*"`

### External Configuration + Feature Toggle (Configuración)

**Objetivo**: eliminar los secretos JWT hardcodeados duplicados en 4 `application.yml` y reemplazar el toggle ad-hoc `gotifyToken.equals("MOCK_TOKEN")` por un mecanismo formal.

**External Configuration**: secretos inyectados como variables de entorno con defaults seguros para desarrollo:

```yaml
jwt:
  secret: ${JWT_SECRET:dev-default}
qr:
  secret: ${QR_SECRET:dev-default}
```

**Feature Toggle**: `MockPushServiceImpl` (activo por defecto) y `PushServiceImpl` (activo cuando `features.push.real-delivery=true`) son beans mutuamente excluyentes controlados por `@ConditionalOnProperty`.

Variables de entorno requeridas en producción: `JWT_SECRET`, `QR_SECRET`, `IDENTITY_SERVICE_URL`, `PROMOTION_SERVICE_URL`, `GOTIFY_URL`, `GOTIFY_TOKEN`, `PUSH_REAL_DELIVERY`.

**ADR-0002**: Se descartó Spring Cloud Config Server (infra adicional innecesaria), HashiCorp Vault (enterprise, fuera del alcance) y Togglz (UI + BD persistence para un caso simple).

**Test**: `./gradlew :services:circleguard-notification-service:test --tests "*PushServiceToggleTest*"`

### Cache-Aside en gateway-service (Performance)

**Objetivo**: reducir latencia en el hot path de validación QR y aislar el gate de caídas de Redis.

Cada scan de QR ejecuta (1) verificación HMAC del JWT y (2) consulta a Redis. Con Caffeine L1 local, validaciones repetidas del mismo token dentro de 30 segundos se sirven en microsegundos sin red.

**Configuración**: Caffeine TTL 30 segundos, capacidad máxima 10,000 entradas, `recordStats()` activo.

**Regla de cache**: solo tokens GREEN se cachean (`unless = "!#result.valid"`). Tokens con estado de riesgo siempre consultan Redis para reflejar cambios de estado inmediatamente.

**Fallback ante Redis caído**: `getStatusFromRedis()` atrapa cualquier excepción, loguea `WARN` y retorna `null` (modo degradado — acceso permitido), evitando que un fallo de infraestructura genere un falso negativo de seguridad.

**ADR-0003**: Se descartó Redis como L1 cache (dependencia circular: Redis es también el store de estado), Spring Session + Redis (gateway es stateless) y cache sin TTL (token puede invalidarse por cambio de estado).

**Test**: `./gradlew :services:circleguard-gateway-service:test --tests "*QrValidationCacheTest*"`

---

# 4. Pipeline de Desarrollo (Dev)

## 4.1 Resumen

El pipeline (`Jenkinsfile.dev`) opera como un **Multibranch Pipeline** en Jenkins, con cada branch teniendo su pipeline aislado. Despliega en el namespace `circleguard-dev`.

| # | Etapa | Tipo | Descripción |
|---|---|---|---|
| 1 | Checkout | Secuencial | `checkout scm` + `chmod +x gradlew` |
| 2 | Prepare | Secuencial | Pre-descarga Gradle wrapper para evitar race conditions en paralelo |
| 3 | Build JARs | Paralelo | `bootJar -x test --no-daemon` para los 8 servicios |
| 4 | Unit Tests | Paralelo | JUnit 5 + Mockito, resultados publicados como JUnit XML |
| 5 | Integration Tests | Paralelo | 6 servicios con tests reales; `promotion-service` omitido (Testcontainers + macOS) |
| 6 | SonarQube Analysis | Secuencial | Análisis estático + cobertura JaCoCo; Quality Gate reporta (no bloquea) |
| 7 | Docker Build `:dev` | Paralelo | Construye imágenes con tag `:dev` |
| 8 | Trivy Scan | Secuencial | Escaneo de imágenes + IaC; `exit-code=0` (no bloquea) |
| 9 | Deploy Dev | Secuencial | `kubectl apply` con `sed` para namespace, imagen y NodePorts |
| 10 | Smoke Tests | Secuencial | `curl` a `host.docker.internal` NodePorts 31082-31088 |
| 11 | E2E Tests | Secuencial | `bash e2e/run_e2e.sh` con puertos 310XX |
| 12 | Performance Tests | Secuencial | Locust 50 usuarios / 60 s contra NodePorts 310XX |
| 13 | Coverage Reports | Secuencial | JaCoCo XML archivado + publicado en Jenkins Coverage Plugin |

## 4.2 Separación de entornos

| Atributo | Producción | Desarrollo |
|---|---|---|
| Namespace | `circleguard` | `circleguard-dev` |
| Tag de imagen | `:latest` | `:dev` |
| NodePorts servicios | 300XX | 310XX |
| NodePorts infra (Neo4j, MailHog) | NodePort | ClusterIP |

Los manifests de producción se transforman con `sed` al aplicarlos en dev: namespace, tag de imagen y NodePorts se sustituyen explícitamente (sin backreferences, por compatibilidad con BusyBox sed en Alpine Linux).

## 4.3 Etapa Prepare y race condition en Gradle

Sin la etapa `Prepare`, los 8 procesos Gradle compiten por el lock exclusivo del archivo `gradle-8.14-bin.zip` y hacen timeout a los 120 segundos. Al ejecutar `./gradlew --version --no-daemon` de forma secuencial primero, el wrapper queda cacheado en `jenkins_home/.gradle/wrapper/dists/` y los builds paralelos lo encuentran disponible inmediatamente.

## 4.4 Variables de entorno del pipeline

```groovy
environment {
    REGISTRY                              = 'circleguard'
    DEV_NS                                = 'circleguard-dev'
    GRADLE_OPTS                           = '-Dorg.gradle.daemon=false'
    DOCKER_HOST                           = 'unix:///var/run/docker.sock'
    TESTCONTAINERS_RYUK_DISABLED          = 'true'
    TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = '/var/run/docker.sock'
    KUBECONFIG                            = '/var/jenkins_home/kube-jenkins.conf'
}
```

`TESTCONTAINERS_RYUK_DISABLED=true` deshabilita el contenedor Ryuk de Testcontainers que falla en entornos Docker-in-Docker.

---

# 5. Pruebas Completas

## 5.1 Resumen de niveles de prueba

| Tipo | Cantidad | Herramienta principal |
|---|---|---|
| Unitarias (backend) | 39 tests en 20 clases | JUnit 5 + Mockito |
| Integración (backend) | 10 tests en 7 clases | JUnit 5 + @SpringBootTest / H2 / Testcontainers |
| Unitarias (mobile) | 4 archivos de tests | Jest + Testing Library |
| E2E | 7 flujos cross-service | Bash + curl (`e2e/run_e2e.sh`) |
| Rendimiento | 4 clases de usuario | Locust (headless, Docker) |
| Seguridad dinámica | 8 servicios | OWASP ZAP Baseline |
| Seguridad estática | 8 imágenes + IaC | Trivy |
| Cobertura | Reporte por servicio | JaCoCo + SonarQube |

## 5.2 Pruebas Unitarias (backend)

Las pruebas unitarias validan componentes individuales en completo aislamiento: sin Spring context, sin base de datos, sin red. Patrón: `@ExtendWith(MockitoExtension.class)` con dependencias mockeadas.

### GraphCleanupTaskTest (`promotion-service`)

Clase bajo prueba: `GraphCleanupTask` — scheduler que elimina relaciones `ENCOUNTERED` del grafo Neo4j con más de 14 días de antigüedad (política de retención NFR-4: Data Minimization).

| Test | Comportamiento validado |
|---|---|
| `shouldPurgeEncountersOlderThan14Days` | El threshold recibido por el repositorio está en el rango `[ahora - 14d - ε, ahora - 14d + ε]` |
| `shouldNotThrowWhenRepositoryReturnsNull` | El scheduler maneja `null` del repositorio sin NullPointerException |
| `shouldHandleRepositoryExceptionGracefully` | Una `RuntimeException` del repositorio es capturada internamente |

### JwtTokenServiceTest (`auth-service`)

Clase bajo prueba: `JwtTokenService` — genera tokens JWT HS256 para autenticación en todos los microservicios.

| Test | Comportamiento validado |
|---|---|
| `shouldGenerateTokenWithAnonymousIdAsSubject` | El campo `sub` del JWT es el `UUID` del `anonymousId`, nunca la identidad real |
| `shouldIncludePermissionsInToken` | Los permisos del `Authentication` se añaden como claim `permissions` |
| `shouldSetExpirationApproximatelyOneHourFromNow` | El campo `exp` está dentro del rango esperado |

### QrTokenServiceTest (`auth-service`)

Tokens JWT de corta duración para validación en accesos físicos.

| Test | Comportamiento validado |
|---|---|
| `shouldGenerateExpiredTokenWhenExpirationIsVeryShort` | Token con 1 segundo de expiración lanza `ExpiredJwtException` |
| `shouldGenerateDifferentTokensForSameUser` | Dos llamadas sucesivas producen tokens distintos (diferente `iat`) |

### KAnonymityFilterTest (`dashboard-service`)

Motor de privacidad k-anonimidad (FR-23). Enmascara grupos con menos de K usuarios para prevenir re-identificación individual.

| Test | Comportamiento validado |
|---|---|
| `shouldMaskEntireResultWhenTotalUsersBelowDefaultK` | `totalUsers=3` (< K=5) → resultado completo enmascarado |
| `shouldMaskIndividualCountsBelowKWhenTotalSufficient` | `totalUsers=100`, `suspectCount=2` → solo `suspectCount` enmascarado a `"<5"` |
| `shouldNotMaskCountsAtExactlyK` | Conteo exactamente igual a K no se enmascara |

### AnalyticsServiceTest (`dashboard-service`)

Verifica que el filtro k-anonimidad se aplica en la capa de servicio y que el fallback de time-series no expone excepciones al cliente.

### AuditLogServiceTest (`notification-service`)

Verifica que cada despacho de notificación produce un evento de auditoría completo en Kafka con todos los campos requeridos (`eventId`, `timestamp`, `userId`, `channel`, `status`, `correlationId`).

### Otros tests unitarios

`LocationResolutionServiceTest`, `HealthStatusServiceTest`, `StatusLifecycleTest`, `FloorServiceTest`, `LoginControllerTest`, `QrTokenControllerTest`, `UserControllerTest`, `IdentityClientResilienceTest`, `QrValidationServiceTest`, `QrValidationCacheTest`, `GateControllerTest`, `NotificationDispatcherTest`, `PushServiceToggleTest`, `TemplateServiceTest`, `HealthSurveyControllerTest`, `QuestionnaireControllerTest`, `IdentityVaultControllerTest`, `IdentityEncryptionConverterTest`, `FileUploadControllerTest`, `FileStorageServiceTest`.

## 5.3 Pruebas de Integración (backend)

Validan la interacción real entre servicios Spring y sus stores de datos. Se ejecutan con H2 in-memory, `@SpringBootTest` con `@MockBean`, o Testcontainers (Neo4j).

| Clase | Tecnología | Corre en macOS CI |
|---|---|---|
| `GatewayValidationIntegrationTest` | `@SpringBootTest` + `@MockBean StringRedisTemplate` | Sí |
| `QuestionnaireJpaIntegrationTest` | `@DataJpaTest` + H2 | Sí |
| `ExposureNotificationIntegrationTest` | `@SpringBootTest` + `@MockBean` dispatcher | Sí |
| `IdentityVaultServiceIntegrationTest` | `@DataJpaTest` + H2 | Sí |
| `AuthUserRepositoryIntegrationTest` | `@DataJpaTest` + H2 | Sí |
| `AnalyticsControllerIntegrationTest` | `@SpringBootTest` + `@MockBean` datasources | Sí |
| `FileUploadIntegrationTest` | `@SpringBootTest` + MockMvc | Sí |
| `SurveyListenerIntegrationTest` | `@Testcontainers` + Neo4j | **No** — omitido en macOS CI |
| `AdministrativeCorrectionTest` | `@Testcontainers` + Neo4j | **No** — omitido en macOS CI |
| `HealthStatusReevaluationTest` | `@Testcontainers` + Neo4j | **No** — omitido en macOS CI |

**Por qué están omitidos los tests Testcontainers en CI**: Docker Desktop en macOS expone el socket vía proxy (`/run/host-services/docker.proxy.sock`). La librería Java de Testcontainers usa HTTP directo sobre Unix socket, incompatible con el comportamiento del proxy. El resultado es `java.lang.IllegalStateException: Could not find a valid Docker environment`. Los tests pasan correctamente en entornos Linux con Docker nativo.

## 5.4 Pruebas Unitarias (mobile)

Ejecutadas con Jest + React Native Testing Library en `mobile/`:

| Archivo | Qué valida |
|---|---|
| `hooks/useQrToken.test.ts` | Hook que genera, almacena y refresca tokens QR |
| `components/__tests__/DynamicForm.test.tsx` | Renderizado de formularios dinámicos con validación |
| `context/__tests__/AuthContext.test.tsx` | Flujo de autenticación: login → JWT → contexto global |
| `utils/__tests__/storage.test.ts` | Abstracción de almacenamiento seguro (SecureStore nativo vs AsyncStorage web) |

```bash
cd mobile
npm run test:ci    # headless con cobertura + JUnit XML para Jenkins
```

## 5.5 Pruebas E2E

El script `e2e/run_e2e.sh` valida 7 flujos cross-service contra el entorno desplegado en Kubernetes usando `curl`. Se integra en los tres pipelines mediante variables de entorno `E2E_PORT_*` que permiten apuntar a cualquier namespace sin modificar el script.

| Flujo | Servicio | Endpoint | Validación |
|---|---|---|---|
| 1 — Health Check | Los 8 servicios | Endpoints raíz | No `000` ni `5xx` en ninguno |
| 2 — Listado de formularios | form-service | `GET /api/v1/questionnaires` | HTTP 200, 401 o 403 |
| 3 — Analytics del dashboard | dashboard-service | `GET /api/v1/analytics/summary` | HTTP 200, 401 o 403 |
| 4 — Validación de QR | gateway-service | `POST /api/v1/gate/validate` | Campo `status="GREEN"` en JSON |
| 5 — Estado de salud | promotion-service | `GET /api/v1/health/status/{id}` | HTTP 200, 401, 403 o 404 |
| 6 — Permisos de usuario | auth-service | `GET /api/v1/users/permissions/NOTIFY_PRIORITY_ALERTS` | HTTP 200, 401 o 403 |
| 7 — Registro de visitante | identity-service | `POST /api/v1/identities/visitor` | HTTP 200, 401 o 403 |

**Resultado del run de referencia (dev, 2026-05-06)**:
```
Resultados : 10 pasaron | 0 fallaron
Veredicto  : PASS
```

**Credenciales en Jenkins**: tres credenciales tipo Secret Text con IDs `e2e-jwt-token`, `e2e-anon-id`, `e2e-qr-token`.

## 5.6 Pruebas de Rendimiento con Locust

Cuatro clases de usuario simulan comportamientos reales del sistema:

| Clase | Servicio | Peso | Tareas principales |
|---|---|---|---|
| `HealthStatusUser` | promotion-service | 5 | `GET /api/v1/health/status/{id}` |
| `SurveySubmissionUser` | form-service | 2 | `POST /api/v1/surveys`, `GET /api/v1/questionnaires` |
| `GatewayValidationUser` | gateway-service | **8** | `POST /api/v1/gate/validate` |
| `DashboardAnalyticsUser` | dashboard-service | 1 | `GET /api/v1/analytics/summary`, `GET /api/v1/analytics/heatmap` |

`GatewayValidationUser` tiene el mayor peso porque la validación de acceso es la operación más frecuente del sistema.

**Configuración de carga** (`locust/locust.conf`): 50 usuarios concurrentes, spawn-rate 5/s, duración 60 s, modo headless.

**Resultados del run de referencia (stage y master)**:

| Métrica | Resultado | SLA |
|---|---|---|
| Peticiones totales | ~1600 | — |
| RPS promedio | ~28 | > 20 RPS |
| Latencia p50 | ~3 ms | < 200 ms |
| Latencia p95 | ~8 ms | < 500 ms |
| Latencia p99 | ~17 ms | < 1000 ms |
| Fallos 5xx reales | 0 | < 1% |
| Veredicto SLA | **APROBADO** | — |

**Sobre los fallos reportados por Locust**: Locust reporta ~518 "fallos" que en realidad son respuestas 401/403 (endpoints protegidos correctamente) y 404 (actuator de promotion-service sin configurar). No representan errores reales del servidor. El único endpoint con autenticación configurada en el escenario (`POST /api/v1/gate/validate`) tiene 0 fallos reales y p95 = 8 ms.

## 5.7 Pruebas de Seguridad (OWASP ZAP)

El script `zap/run_zap.sh` ejecuta un escaneo pasivo (sin ataques activos) con OWASP ZAP Baseline contra los 8 microservicios en los NodePorts 300XX de producción. Integrado en el pipeline `Jenkinsfile.master` post-deploy.

| Regla suprimida en `zap/rules.tsv` | Justificación |
|---|---|
| Content Security Policy (10038) | No aplica a APIs REST sin frontend |
| Cookie flags (10012, 10011, 10054) | La API usa JWT Bearer, no cookies de sesión |
| CORS abierto (10098) | Intencional — app móvil Expo consume la API |

Las reglas de inyección real (SQL, XSS, XSLT) están marcadas como `FAIL` — bloquean el pipeline si ZAP las detecta.

## 5.8 Cobertura con JaCoCo y SonarQube

JaCoCo se configura en `build.gradle.kts` para todos los subproyectos. Genera reportes XML leídos por SonarQube y reportes HTML archivados en Jenkins.

**Quality Gate "Sonar Way"** (umbrales sobre código nuevo):
- Cobertura de código nuevo >= 80%
- Líneas duplicadas <= 3%
- Maintainability, Reliability y Security Rating: A

El gate es bloqueante en `master` (`abortPipeline: true`) y solo reporta en `dev`/`stage` (el pipeline continúa marcado como `Unstable`).

---

# 6. Pipeline de Stage

## 6.1 Resumen

El pipeline (`Jenkinsfile.stage`) despliega en el namespace `circleguard-stage`. Replica la estructura completa del pipeline dev ajustando namespace, tag de imagen (`:stage`) y NodePorts (320XX).

| Atributo | Producción | Desarrollo | **Stage** |
|---|---|---|---|
| Namespace | `circleguard` | `circleguard-dev` | `circleguard-stage` |
| Tag de imagen | `:latest` | `:dev` | `:stage` |
| NodePorts servicios | 300XX | 310XX | **320XX** |
| Jenkinsfile | `Jenkinsfile.master` | `Jenkinsfile.dev` | `Jenkinsfile.stage` |

## 6.2 Modificaciones backward-compatible

Para que las herramientas de testing existentes apunten a cualquier entorno sin cambiar el script base:

**`e2e/run_e2e.sh`**: se añadieron variables `E2E_PORT_*` con los puertos dev como valor por defecto. El pipeline stage las sobreescribe con los 320XX. El pipeline dev no requirió ninguna modificación.

**`locust/locustfile.py`**: se añadieron variables `LOCUST_HOST_*` por servicio con fallback de tres niveles: variable específica → `LOCUST_HOST` global → default hardcodeado 310XX. El pipeline stage inyecta las variables 320XX mediante `-e LOCUST_HOST_*`.

## 6.3 Readiness Probe y problema de timing

Al ejecutar la primera vez el pipeline stage, `kubectl rollout status` retornaba `successfully rolled out` inmediatamente al iniciar el proceso del contenedor, antes de que Spring Boot terminara (~27 segundos). Los smoke tests recibían HTTP 000 porque Tomcat aún no había enlazado al puerto.

**Solución**: se añadió `readinessProbe` con `tcpSocket` a los 6 manifests de servicio:

```yaml
readinessProbe:
  tcpSocket:
    port: 808X
  initialDelaySeconds: 20
  periodSeconds: 5
  failureThreshold: 12
```

Se eligió `tcpSocket` en lugar de `httpGet` porque los endpoints HTTP requieren autenticación (retornan 401/403) y Kubernetes interpreta cualquier respuesta no-2xx como falla del probe.

## 6.4 Rol del entorno stage como gate pre-producción

| Dimensión | Dev | Stage |
|---|---|---|
| Propósito | Feedback en desarrollo | Gate pre-producción |
| ¿Quién lo dispara? | Cada push a cualquier branch | Antes de promover a master |
| ¿Ejecuta E2E? | Sí (puertos 310XX) | Sí (puertos 320XX) |
| ¿Ejecuta performance? | Sí (puertos 310XX) | Sí (puertos 320XX) |
| ¿Release Notes? | No | No |

---

# 7. Pipeline de Producción (Master)

## 7.1 Resumen

El pipeline (`Jenkinsfile.master`) despliega en el namespace canónico `circleguard`. A diferencia de dev y stage, **no aplica transformaciones `sed`**: los manifests en `k8s/infra/` y `k8s/services/` ya describen el estado de producción (namespace `circleguard`, tag `:latest`, NodePorts 300XX).

La adición clave respecto a los pipelines anteriores es la etapa **Release Notes** con versionado semántico automático.

| # | Etapa | Diferencias respecto a dev/stage |
|---|---|---|
| 7 | Deploy Master | `kubectl apply` directo, sin transformaciones `sed` |
| 11 | Release Notes | Exclusivo de master: semver + Markdown + tag Git |
| — | Quality Gate | `abortPipeline: true` (bloquea en prod) |
| — | Trivy Scan | `TRIVY_EXIT_CODE=1` (bloquea ante HIGH/CRITICAL) |

## 7.2 Por qué la ausencia de sed transforms es una propiedad de diseño

Los manifests son la **fuente de verdad de producción**. Los pipelines dev y stage derivan de ellos; el pipeline master los usa directamente. Esto tiene dos beneficios concretos: (1) reduce errores operacionales eliminando una fuente de transformación; (2) lo que se ve en `k8s/services/*.yml` es exactamente lo que se despliega en producción, sin intermediarios.

## 7.3 Generación de Release Notes

Las Release Notes son el artefacto formal que cierra el ciclo de un cambio en producción. En el marco ITIL, corresponden al Change Record que documenta qué cambió, quién lo introdujo y cuándo fue desplegado.

**Lógica del script `scripts/semver.sh`**:

```bash
# 1. Encontrar el tag más reciente antes del commit actual
PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
RANGE="${PREV_TAG:-HEAD~10}..HEAD"

# 2. Calcular bump (MAJOR/MINOR/PATCH) desde Conventional Commits
# MAJOR: BREAKING CHANGE o tipo!
# MINOR: feat:
# PATCH: fix:, docs:, chore:, etc.
```

**Reglas de bump**:

| Tipo de commit | Bump | Ejemplo |
|---|---|---|
| `BREAKING CHANGE` en cuerpo/pie | **MAJOR** | `feat!: migrar API a v2` |
| `feat:` | **MINOR** | `feat(gateway): validación QR multifactor` |
| `fix:` / `chore:` / `docs:` / otros | **PATCH** | `fix(promotion): corregir cascade null` |

El tag Git ligero creado en cada release permite:
- `git log v1.0.41..v1.0.42` — ver exactamente qué entró en cada release
- `git checkout v1.0.41` — recrear el estado de cualquier release anterior
- `git describe --tags` — determinar la versión exacta de cualquier build

---

# 8. CI/CD Avanzado

## 8.1 Análisis Estático con SonarQube

SonarQube se levanta con un Compose dedicado (`sonarqube/docker-compose.sonarqube.yml`, puerto 9000). El plugin `org.sonarqube` en `build.gradle.kts` y JaCoCo por subproyecto permiten analizar los 8 servicios en una sola ejecución: `./gradlew sonar`.

**Configuración en Jenkins**: plugin SonarQube Scanner + servidor `sonarqube` en `Configure System` + credencial `sonar-token` + webhook `http://host.docker.internal:8080/sonarqube-webhook/`.

## 8.2 Escaneo de Vulnerabilidades con Trivy

Trivy se ejecuta vía imagen Docker oficial, montando el socket del daemon. Escanea dos targets:

1. **Imágenes Docker** (`trivy image`): CVEs en librerías JAR del classpath y en la imagen base JDK 21 Temurin.
2. **IaC** (`trivy config`): misconfiguraciones en manifests Kubernetes y módulos Terraform.

Los 8 servicios se escanean en bucle. Los reportes HTML se archivan como artefactos Jenkins.

Gate por entorno: `TRIVY_EXIT_CODE=0` en dev/stage (reporta sin bloquear), `TRIVY_EXIT_CODE=1` en prod (bloquea ante HIGH/CRITICAL).

El pipeline `Jenkinsfile.security` ejecuta ambos tipos de scan cada noche (`H 2 * * *`), independientemente del flujo de entrega.

## 8.3 Versionado Semántico Automático

El script `scripts/semver.sh` reemplaza el versionado manual `v1.0.${BUILD_NUMBER}` con versiones semánticamente significativas. Lee los commits desde el último tag y aplica las reglas del estándar Conventional Commits (ver sección 7.3).

`v1.0.42` no comunica nada sobre la naturaleza del cambio. `v1.2.0` indica nueva funcionalidad; `v2.0.0` indica cambio incompatible.

## 8.4 Notificaciones Automáticas de Fallo

MailHog (`mailhog:1025`) actúa como relay SMTP de desarrollo sin credenciales ni TLS. El plugin Email Extension de Jenkins envía emails en los eventos `post.failure` y `post.unstable` de los tres pipelines.

| Evento | Destinatario | Asunto |
|---|---|---|
| Fallo en dev/stage | devops@circleguard.local | `[FALLO] <job> #<N> (<branch>)` |
| Build inestable (QG degradado) | devops@circleguard.local | `[INESTABLE] <job> #<N>` |
| Fallo en producción | devops@circleguard.local | `[FALLO] PRODUCCION <job> #<N>` |

---

# 9. Change Management y Release Notes

## 9.1 Proceso Formal de Change Management

CircleGuard implementa un proceso de Change Management basado en **ITIL v4** adaptado a equipo pequeño con GitFlow y CI/CD automatizado.

### Tipos de cambio

| Tipo | Criterios concretos | Ruta GitFlow | Aprobación requerida |
|---|---|---|---|
| **Standard** | Cambios en `test/`, `docs/`, logging, bump PATCH sin CVE | `feature/* → develop → Jenkinsfile.dev` | No (automático) |
| **Normal** | Cambios en `src/main/`, `k8s/`, Jenkinsfiles, bump MINOR o MAJOR | `develop → release/* → master → Jenkinsfile.stage/master` | Sí (PR + gate Jenkins) |
| **Emergency** | Hotfix con incidente activo, vulnerabilidad CVSS >= 9.0 post-deploy | `hotfix/* → master → develop` | Sí (pipeline + verbal) |

### Roles

| Rol | Responsabilidad | Herramienta |
|---|---|---|
| **Solicitante / Desarrollador** | Crea `feature/*` o `hotfix/*`, commits Conventional Commits, abre PR | GitHub Pull Request |
| **Revisor técnico** | Revisa código, verifica tests y calidad | GitHub PR review |
| **Ejecutor de producción** | Aprueba en gate `Approval (Prod)` de Jenkins | Jenkins `input` stage |
| **Responsable de operaciones** | Monitorea despliegue, ejecuta smoke/E2E post-deploy | Jenkins + kubectl |

### Criterios de aceptación (Definition of Done para producción)

- Todos los builds Java compilan sin errores.
- Tests unitarios pasan al 100%.
- Tests de integración pasan al 100%.
- Mobile tests pasan (`npm run test:ci`).
- SonarQube Quality Gate en estado `OK`.
- Trivy sin CVEs HIGH/CRITICAL sin mitigación en `.trivyignore`.
- PR revisado y aprobado.
- Gate `Approval (Prod)` aprobado explícitamente en Jenkins.
- Smoke Tests pasan en namespace `circleguard`.
- E2E Tests pasan (7 flujos sin errores).

## 9.2 Planes de Rollback

### Restricción de despliegue local

Los manifests declaran `imagePullPolicy: Never`. Kubernetes solo usa imágenes presentes en el daemon local. El pipeline de master escala todos los deployments a 0 réplicas en `post.always` para conservar recursos; al restaurar es necesario re-escalar.

### Tabla de escenarios

| Escenario | Señal de alerta | Acción | Tiempo estimado |
|---|---|---|---|
| Deploy fallido (CrashLoopBackOff) | Jenkins falla, pods no llegan a `Running` | `kubectl rollout undo` | 2-5 min |
| Regresión funcional post-deploy | E2E/Smoke fallan | `kubectl rollout undo` + verificación smoke | 5-10 min |
| Vulnerabilidad crítica post-deploy | CVE reportado | Checkout tag anterior → rebuild → redeploy | 15-30 min |
| Fallo de base de datos / migración | Logs de error en pods | Rollout undo + restore backup | Variable |

### Plan A — Rollback rápido (revisión K8s anterior)

```bash
# Ver historial de revisiones
kubectl rollout history deployment/auth-service -n circleguard

# Revertir a revisión anterior
kubectl rollout undo deployment/auth-service -n circleguard

# Revertir a revisión específica
kubectl rollout undo deployment/auth-service -n circleguard --to-revision=2

# Re-escalar si el post.always los dejó en 0
kubectl scale deployment --all -n circleguard --replicas=1
```

Script automatizado: `bash scripts/rollback.sh <servicio|all> [--to-revision N]`

### Plan B — Rollback por versión (tag Git anterior)

```bash
# Identificar versión objetivo
git tag --sort=-version:refname

# Crear rama de rollback desde el tag
git checkout -b rollback/v0.2.1 v0.2.1

# Reconstruir imágenes y recargar en el clúster
docker build -t circleguard/auth-service:latest services/auth-service/
# ... repetir para los 8 servicios o ejecutar pipeline en esa rama

# Forzar re-deploy
kubectl rollout restart deployment --all -n circleguard
```

### Plan C — Verificación post-rollback

```bash
kubectl get pods -n circleguard
kubectl scale deployment --all -n circleguard --replicas=1
curl -s -o /dev/null -w "%{http_code}" http://localhost:30087/health   # gateway
curl -s -o /dev/null -w "%{http_code}" http://localhost:30082/actuator/health  # notification
# ... repetir para los 8 servicios
```

## 9.3 CHANGELOG

El archivo `CHANGELOG.md` en la raíz del repositorio mantiene el historial consolidado de releases siguiendo el formato **Keep a Changelog** con **SemVer**. Difiere de las Release Notes automáticas en que está orientado a stakeholders y se actualiza manualmente o con script.

| Artefacto | Generado por | Contenido | Audiencia |
|---|---|---|---|
| `release-notes-vX.Y.Z.md` | Pipeline Jenkins (automático) | Commits clasificados + metadata de build | Equipo técnico / auditoría |
| `CHANGELOG.md` | Actualización manual | Resumen legible de cada versión | Stakeholders / equipo |

---

# 10. Observabilidad y Monitoreo

## 10.1 Resumen del Stack

| Componente | Propósito | Acceso producción |
|---|---|---|
| Prometheus | Scrape de métricas + reglas de alerta | `http://localhost:30090` |
| Grafana | Dashboards técnicos y de negocio | `http://localhost:30091` |
| Elasticsearch | Almacenamiento de logs JSON | Interno |
| Logstash | Parseo y enrutamiento de logs | Interno |
| Kibana | UI de logs y búsqueda | `http://localhost:30092` |
| Filebeat | Recolección de logs de pods (DaemonSet) | Interno |
| Zipkin | Tracing distribuido | `http://localhost:30093` |
| Alertmanager | Enrutamiento de alertas → MailHog SMTP | `http://localhost:30094` |

## 10.2 Prometheus + Grafana

Prometheus scrape métricas de los 8 servicios vía `GET /actuator/prometheus` (scrape estático a `<svc-svc>:<port>`).

La configuración de Actuator se inyecta vía ConfigMap:

```yaml
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE: "health,info,prometheus,metrics"
MANAGEMENT_ENDPOINT_HEALTH_PROBES_ENABLED: "true"
MANAGEMENT_TRACING_SAMPLING_PROBABILITY:   "1.0"
MANAGEMENT_ZIPKIN_TRACING_ENDPOINT:        "http://zipkin-svc:9411/api/v2/spans"
```

**Dashboard técnico por servicio**: variable `$service` → dropdown que cubre los 8 servicios. Paneles: HTTP request rate, HTTP error rate (5xx%), latencia p50/p95/p99, JVM heap, threads activos, GC time, estado UP/DOWN.

**Dashboard de métricas de negocio**: `circleguard_logins_total`, `circleguard_surveys_submitted_total`, `circleguard_health_status_updates_total`, `circleguard_notifications_sent_total`.

## 10.3 ELK Stack

Cada servicio emite logs en formato JSON a stdout usando `logback-spring.xml` con `LogstashEncoder`. El JSON incluye `traceId`, `spanId` y `parentId` inyectados por Micrometer Tracing.

**Flujo**: pods → stdout JSON → CRI/containerd → Filebeat DaemonSet → Logstash → Elasticsearch (índice `circleguard-logs-YYYY.MM.dd`) → Kibana.

Kibana: patrón de índice `circleguard-logs-*`, campo de tiempo `@timestamp`. Buscar por `traceId` para correlacionar logs con trazas.

## 10.4 Tracing Distribuido (Zipkin)

Dependencias añadidas a los 8 servicios: `micrometer-tracing-bridge-brave` + `zipkin-reporter-brave`. Sampling al 100% en desarrollo/stage.

Los headers B3 (`X-B3-TraceId`, `X-B3-SpanId`) se propagan automáticamente entre servicios en llamadas HTTP. Zipkin muestra el árbol completo de spans para cada request cross-service.

## 10.5 Alertas (Prometheus + Alertmanager)

| Alerta | Expresión PromQL | Severidad | Ventana |
|---|---|---|---|
| `ServiceDown` | `up == 0` | critical | 1 min |
| `HighErrorRate` | `rate(http_server_requests_seconds_count{outcome="SERVER_ERROR"}[5m]) / rate(...[5m]) > 0.05` | warning | 5 min |
| `HighLatencyP99` | `histogram_quantile(0.99, rate(http_server_requests_seconds_bucket[5m])) > 1.0` | warning | 5 min |
| `HighJvmHeapUsage` | `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} > 0.90` | warning | 5 min |
| `NoHealthStatusUpdates` | `increase(circleguard_health_status_updates_total[1h]) == 0` | info | inmediata |

`ServiceDown` usa `for: 1m` porque un pod caído es un incidente inmediato. Las demás alertas usan `for: 5m` para filtrar spikes transitorios y evitar alert fatigue.

Alertmanager enruta todas las alertas al receiver SMTP conectado a MailHog (`mailhog-svc:1025`).

## 10.6 Health Checks y Probes

Todos los manifests de servicio usan probes HTTP con Spring Actuator:

```yaml
startupProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 808X
  initialDelaySeconds: 20
  periodSeconds: 5
  failureThreshold: 30     # hasta 170 s total; Spring Boot + Neo4j/Redis/Kafka puede tardar ~90 s

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 808X
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 808X
  periodSeconds: 5
  failureThreshold: 6
```

`startupProbe.failureThreshold: 30` con `periodSeconds: 5` da 170 segundos totales para el arranque. Sin `startupProbe`, `livenessProbe` mataría el pod antes de que Spring Boot termine de inicializar el contexto con Neo4j + Redis + Kafka.

## 10.7 Métricas de Negocio (Custom Counters)

| Métrica | Tag(s) | Servicio |
|---|---|---|
| `circleguard_logins_total` | `result=success\|failure` | auth-service |
| `circleguard_surveys_submitted_total` | — | form-service |
| `circleguard_health_status_updates_total` | `status` | promotion-service |
| `circleguard_notifications_sent_total` | `channel`, `result` | notification-service |
| `circleguard_gate_validations_total` | `result=granted\|denied` | gateway-service |
| `circleguard_identity_mappings_total` | — | identity-service |
| `circleguard_file_uploads_total` | `result=success\|failure` | file-service |
| `circleguard_dashboard_queries_total` | `endpoint=trends\|health-board\|summary\|...` | dashboard-service |

---

# 11. Seguridad

## 11.1 Escaneo Continuo de Vulnerabilidades

Trivy corre en dos momentos del ciclo de desarrollo:

1. **En el pipeline de entrega** (`Jenkinsfile.dev/stage/master`): etapas `Trivy Scan` (imágenes Docker) y `Trivy IaC Scan` (manifests Kubernetes + módulos Terraform). En dev/stage no bloquea (`exit-code=0`); en prod bloquea ante HIGH/CRITICAL (`exit-code=1`).

2. **Pipeline programado nocturno** (`Jenkinsfile.security`): ejecuta ambos tipos de scan cada noche (`H 2 * * *`), independientemente del flujo de entrega. Notifica por email si detecta vulnerabilidades.

El archivo `.trivyignore` lista CVEs aceptados conscientemente. Política: ninguna entrada sin comentario de justificación.

## 11.2 Gestión Segura de Secretos

`terraform/modules/k8s-config/main.tf` materializa el Secret `circleguard-secrets` con 15 claves leyendo valores desde AWS Secrets Manager (LocalStack en dev). Los pods los consumen vía `envFrom: secretRef`.

**Correcciones aplicadas**: `auth-service` e `identity-service` tenían secretos (`SPRING_LDAP_PASSWORD`, `VAULT_SECRET`, `VAULT_SALT`, `VAULT_HASH_SALT`) duplicados en texto plano en el `extra_env` inline del módulo Terraform. Se eliminaron del `extra_env`; los valores llegan ahora exclusivamente por `envFrom`.

Los valores en `k8s/infra/02-secrets.yml` (base64 hardcodeado) son solo para entorno de desarrollo local (kind). En producción real, los secretos se inyectan desde AWS Secrets Manager o un gestor externo (Vault, Sealed Secrets, ESO).

## 11.3 RBAC para Acceso a Recursos

**ServiceAccounts por microservicio**: cada uno de los 8 microservicios tiene su propia `ServiceAccount` con `automountServiceAccountToken: false`. Las apps Spring Boot no consumen la API de Kubernetes — montar el token del SA `default` es superficie de ataque innecesaria.

**Roles namespaced**:

| Rol | Recursos | Verbos | Propósito |
|---|---|---|---|
| `circleguard-developer` (solo lectura) | pods, pods/log, services, configmaps, deployments, replicasets | get, list, watch | Operadores y SREs inspeccionan sin poder modificar |
| `circleguard-ci-deployer` (despliegue) | services, configmaps, pods, deployments, replicasets | get, list, watch, create, update, patch, delete | Jenkins aplica manifests sin necesitar `cluster-admin` |

Ambos Roles son `kind: Role` (namespaced, no `ClusterRole`). No incluyen acceso a `secrets`, `ingresses` ni `namespaces`.

## 11.4 TLS para Servicios Expuestos Públicamente

**ingress-nginx** instalado vía Helm con NodePorts por ambiente (30443 prod, 31443 dev, 32443 stage).

**Certificado TLS self-signed** generado por `hashicorp/tls` directamente en Terraform: RSA 2048, CN `circleguard.local`, validez 365 días. En producción real se reemplazaría por cert-manager con Let's Encrypt.

**Ingress**: el tráfico HTTPS a `circleguard.local` es terminado en ingress-nginx y enrutado como HTTP interno al `gateway-service`. Los demás servicios no están expuestos externamente.

```bash
# Probar TLS local (acepta cert self-signed)
echo "127.0.0.1 circleguard.local" | sudo tee -a /etc/hosts
curl -k -H 'Host: circleguard.local' https://localhost:31443/
```

---

# 12. Costos de Infraestructura

## 12.1 Entorno actual: costo $0

El entorno de desarrollo usa Docker Desktop con LocalStack. Costo operativo en desarrollo: **$0**.

## 12.2 Totales del clúster (recursos Kubernetes)

| Capa | CPU requests | RAM requests |
|---|---|---|
| Microservicios (8) | ~1.3 vCPU | ~3.75 Gi |
| Observabilidad (8 componentes) | ~1.0 vCPU | ~2.6 Gi |
| Infraestructura de datos (6 componentes) | ~1.3 vCPU | ~1.8 Gi |
| **Total** | **~3.6 vCPU** | **~8.15 Gi** |

## 12.3 Estimación en AWS (us-east-1, precios aprox. junio 2026)

| Opción | Configuración | Precio/mes |
|---|---|---|
| **A — Nodo único** | EC2 t3.2xlarge (8 vCPU, 32 Gi) + EKS + storage + bandwidth | ~$326 |
| **B — Multi-nodo prod** | 4 EC2 t3.xlarge/large + EKS + storage + S3 + Secrets Manager | ~$515 |
| **C — Desarrollo local** | Docker Desktop + LocalStack | **$0** |

## 12.4 Optimizaciones de costo

| Estrategia | Ahorro estimado |
|---|---|
| EC2 Spot Instances para nodos de stage | ~60-70% en compute de stage |
| Reserved Instances (1 año) para prod | ~30-40% en compute de prod |
| Compartir clúster entre dev y stage (namespaces) | Eliminar 1-2 nodos |
| Apagar entorno stage fuera de horario laboral | ~65% en compute de stage |

---

# 13. Manual de Operaciones

## 13.1 Accesos y URLs por entorno

| Herramienta | Dev (31xxx) | Stage (32xxx) | Prod (30xxx) |
|---|---|---|---|
| Jenkins | `http://localhost:8080` | — | — |
| Grafana | `http://localhost:31091` | `http://localhost:32091` | `http://localhost:30091` |
| Kibana | `http://localhost:31092` | `http://localhost:32092` | `http://localhost:30092` |
| Zipkin | `http://localhost:31093` | `http://localhost:32093` | `http://localhost:30093` |
| Alertmanager | `http://localhost:31094` | `http://localhost:32094` | `http://localhost:30094` |
| Prometheus | `http://localhost:31090` | `http://localhost:32090` | `http://localhost:30090` |
| MailHog | `http://localhost:31025` | — | `http://localhost:30025` |

Credenciales Grafana: `admin` / `circleguard`.

## 13.2 Despliegue y arranque

```bash
# Con Terraform (recomendado)
cd terraform/envs/prod && terraform init && terraform apply -auto-approve

# Con kubectl (manifests directos)
kubectl apply -f k8s/infra/ -n circleguard
kubectl apply -f k8s/services/ -n circleguard
```

## 13.3 Verificación de salud

```bash
# Estado de todos los pods
kubectl get pods -n circleguard

# Health check HTTP de los 8 microservicios (prod NodePorts)
for port in 30082 30083 30084 30085 30086 30087 30088 30180; do
  echo -n "Puerto $port: "
  curl -s http://host.docker.internal:$port/actuator/health | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))"
done

# Targets de Prometheus (8 servicios deben estar UP)
curl -s 'http://localhost:30090/api/v1/query?query=up' | \
  python3 -c "import sys,json; d=json.load(sys.stdin); \
  [print(r['metric'].get('job','?'), r['value'][1]) for r in d['data']['result']]"
```

## 13.4 Logs y trazas

```bash
# Últimas 100 líneas de un servicio
kubectl logs -n circleguard -l app=circleguard-auth-service --tail=100

# Buscar por traceId en Kibana
# Discover → index circleguard-* → filtro: traceId: <id>
```

## 13.5 Rollback de un servicio

```bash
kubectl rollout history deployment/circleguard-auth-service -n circleguard
kubectl rollout undo deployment/circleguard-auth-service -n circleguard
kubectl rollout status deployment/circleguard-auth-service -n circleguard

# Rollback completo del entorno via Terraform
cd terraform/envs/prod
git checkout <tag-anterior>
terraform apply -auto-approve
```

## 13.6 Escalado manual

```bash
kubectl scale deployment circleguard-gateway-service --replicas=3 -n circleguard
kubectl get pods -n circleguard -l app=circleguard-gateway-service
```

`promotion-service` es el servicio más intensivo (1 Gi RAM request, 2 Gi limit). Escalar requiere suficiente capacidad en el nodo.

## 13.7 Troubleshooting común

| Síntoma | Causa probable | Diagnóstico |
|---|---|---|
| Pod en `CrashLoopBackOff` | Init container falla (BD no lista) | `kubectl describe pod <pod> -n <ns>` — ver eventos |
| `503 Service Unavailable` desde gateway | Servicio destino caído | `up{job="circleguard-<svc>"}` en Prometheus |
| Logs no aparecen en Kibana | Filebeat o Logstash caído | `kubectl get pods -n <ns> \| grep -E "filebeat\|logstash"` |
| QR token rechazado con 401 | `QR_SECRET` distinto entre auth y gateway | `kubectl get configmap circleguard-config -n <ns> -o yaml \| grep QR_SECRET` |
| Kafka consumer lag creciente | promotion o notification saturados | Ver métricas JVM heap en Grafana → escalar réplicas |
| Trazas no aparecen en Zipkin | `MANAGEMENT_ZIPKIN_TRACING_ENDPOINT` incorrecto | `kubectl get configmap circleguard-config -n <ns> -o yaml \| grep ZIPKIN` |

## 13.8 Backup y restauración

**PostgreSQL**:
```bash
# Backup
kubectl exec -n circleguard deploy/postgres -- \
  pg_dump -U circleguard circleguard_db > backup-$(date +%Y%m%d).sql

# Restaurar
kubectl exec -i -n circleguard deploy/postgres -- \
  psql -U circleguard circleguard_db < backup-20260609.sql
```

**Neo4j** (modo offline):
```bash
kubectl scale deployment neo4j --replicas=0 -n circleguard
kubectl exec -n circleguard deploy/neo4j -- \
  neo4j-admin database dump neo4j --to-stdout > neo4j-backup-$(date +%Y%m%d).dump
kubectl scale deployment neo4j --replicas=1 -n circleguard
```

## 13.9 Teardown

```bash
# Destruir entorno completo con Terraform
cd terraform/envs/prod && terraform destroy -auto-approve

# O solo un servicio
kubectl delete deployment circleguard-auth-service -n circleguard
```
