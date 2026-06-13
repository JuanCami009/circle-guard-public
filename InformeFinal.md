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

**Construir la imagen personalizada** (desde la raíz del repositorio):

```bash
docker build -t circleguard/jenkins:latest jenkins/
```

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

**Configuración inicial de Jenkins:**

1. Abrir `http://localhost:8080`.
2. Obtener la contraseña inicial: `docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword`
3. Seleccionar **Install suggested plugins**.
4. Crear el usuario administrador y confirmar la URL.

Luego ir a **Manage Jenkins → Plugins → Available plugins** e instalar:

| Plugin | Función |
|---|---|
| `Docker Pipeline` | Construir y publicar imágenes Docker desde Jenkinsfile |
| `Kubernetes CLI` | Acceso a `kubectl` en los pipelines |
| `SonarQube Scanner` | Análisis estático + Quality Gate |
| `Email Extension` | Notificaciones de fallo vía SMTP |
| `Coverage Plugin` | Publicar reportes JaCoCo en la UI de Jenkins |

**Kubeconfig parcheado**: el kubeconfig montado apunta a `127.0.0.1:6443`. Se crea una copia parcheada con `host.docker.internal:6443` persistida en `jenkins_home` y referenciada por `KUBECONFIG=/var/jenkins_home/kube-jenkins.conf` en todos los pipelines:

```bash
docker exec jenkins cp /var/jenkins_home/.kube/config /var/jenkins_home/kube-jenkins.conf
CONTEXT=$(docker exec jenkins kubectl --kubeconfig=/var/jenkins_home/kube-jenkins.conf config current-context)
docker exec jenkins kubectl --kubeconfig=/var/jenkins_home/kube-jenkins.conf \
    config set-cluster "$CONTEXT" \
    --server=https://host.docker.internal:6443 \
    --insecure-skip-tls-verify=true
```

El kubeconfig original del host **no se modifica**. Este archivo parcheado persiste en el volumen `jenkins_home` y sobrevive reinicios del contenedor.

## 2.3 Dockerfiles — Estrategia Multi-Stage

Cada microservicio tiene su `Dockerfile` en `services/<nombre>/Dockerfile`. Todos siguen el mismo patrón de dos etapas:

**Etapa 1 - builder** (`eclipse-temurin:21-jdk-alpine`): compila el JAR ejecutable con Gradle.

**Etapa 2 - runtime** (`eclipse-temurin:21-jre-alpine`): imagen final mínima (~200 MB) que copia únicamente el JAR. Ejecuta como usuario no-root (`appuser`, UID 1001) por seguridad y compatibilidad con `runAsNonRoot: true` en Kubernetes.

El **contexto de build siempre es la raíz del repositorio** porque `settings.gradle.kts` y `build.gradle.kts` residen ahí y Gradle debe ver todos los módulos del monorepo.

**Construir las imágenes manualmente** (desde la raíz del repositorio):

```bash
docker build -t circleguard/file-service:latest        -f services/circleguard-file-service/Dockerfile .
docker build -t circleguard/gateway-service:latest     -f services/circleguard-gateway-service/Dockerfile .
docker build -t circleguard/dashboard-service:latest   -f services/circleguard-dashboard-service/Dockerfile .
docker build -t circleguard/form-service:latest        -f services/circleguard-form-service/Dockerfile .
docker build -t circleguard/notification-service:latest -f services/circleguard-notification-service/Dockerfile .
docker build -t circleguard/promotion-service:latest   -f services/circleguard-promotion-service/Dockerfile .
docker build -t circleguard/auth-service:latest        -f services/circleguard-auth-service/Dockerfile .
docker build -t circleguard/identity-service:latest    -f services/circleguard-identity-service/Dockerfile .
```

Los pipelines CI/CD construyen las imágenes con el JAR pre-compilado en la etapa `Build JARs`. El `Dockerfile` de runtime copia el JAR desde `services/*/build/libs/*.jar` sin re-invocar Gradle, reduciendo el tiempo de esta etapa de ~5 minutos a ~10 segundos por servicio.

## 2.4 Kubernetes — Estructura de Manifests

**Secuencia de despliegue manual:**

```bash
kubectl config use-context docker-desktop
kubectl apply -f k8s/00-namespace.yml
kubectl apply -f k8s/infra/

# Esperar infraestructura crítica antes de los servicios
kubectl wait --for=condition=ready pod -l app=postgres -n circleguard --timeout=120s
kubectl wait --for=condition=ready pod -l app=neo4j    -n circleguard --timeout=120s

kubectl apply -f k8s/services/
```

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

**Diagrama de despliegue:**

![Deployment CircleGuard](Deployment%20CircleGuard.jpg)

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

## 4.1 Configurar el Multibranch Pipeline en Jenkins

1. Abrir Jenkins en `http://localhost:8080` → **New Item**.
2. Ingresar el nombre `circleguard-dev-pipeline`.
3. Seleccionar **Multibranch Pipeline** → **OK**.
4. En **Branch Sources**: Add source → Git → URL del repositorio. Discover branches: All branches.
5. En **Build Configuration**:

| Campo | Valor |
|---|---|
| Mode | by Jenkinsfile |
| Script Path | `Jenkinsfile.dev` |

6. **Save** → Jenkins ejecuta Branch Indexing automáticamente y crea un sub-pipeline por cada branch que contenga `Jenkinsfile.dev`.

## 4.2 Resumen

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

## 4.3 Separación de entornos

| Atributo | Producción | Desarrollo |
|---|---|---|
| Namespace | `circleguard` | `circleguard-dev` |
| Tag de imagen | `:latest` | `:dev` |
| NodePorts servicios | 300XX | 310XX |
| NodePorts infra (Neo4j, MailHog) | NodePort | ClusterIP |

Los manifests de producción se transforman con `sed` al aplicarlos en dev: namespace, tag de imagen y NodePorts se sustituyen explícitamente (sin backreferences, por compatibilidad con BusyBox sed en Alpine Linux).

## 4.4 Descripción de etapas clave

**Checkout**: `checkout scm` + `chmod +x gradlew`. El `chmod` es necesario porque Jenkins clona sin preservar permisos del Gradle wrapper.

**Build JARs (paralelo)**: flags usados en cada servicio:

| Flag | Razón |
|---|---|
| `:services:<name>:bootJar` | Compila solo el servicio específico |
| `-x test` | Omite pruebas (etapa dedicada posterior) |
| `--no-daemon` | Evita que el daemon Gradle quede en segundo plano en Jenkins |

**Deploy Dev**: aplica transformaciones `sed` sobre los manifests de producción. Usa reemplazos explícitos (sin backreferences) por compatibilidad con BusyBox sed en Alpine Linux:

```bash
# Infra: namespace y NodePorts a ClusterIP
sed -E -e 's/namespace: circleguard$/namespace: circleguard-dev/g' \
       -e 's/type: NodePort/type: ClusterIP/g' \
       -e '/nodePort:/d' "$f" | kubectl apply -f -

# Servicios: namespace, tag :latest→:dev y NodePorts 300XX→310XX
sed -e 's/namespace: circleguard$/namespace: circleguard-dev/g' \
    -e 's/:latest/:dev/g' \
    -e 's/nodePort: 30082/nodePort: 31082/g' \
    -e 's/nodePort: 30087/nodePort: 31087/g' \
    # ... resto de puertos explícitos
    "$f" | kubectl apply -f -
```

**Smoke Tests**: `curl` vía `host.docker.internal` (los NodePorts son puertos del nodo Kubernetes = host, no del contenedor Jenkins donde corre el pipeline). Códigos aceptables: `200`, `401`, `403`, `404`. Solo `000` (connection refused) es fallo real.

## 4.5 Etapa Prepare y race condition en Gradle

Sin la etapa `Prepare`, los 8 procesos Gradle compiten por el lock exclusivo del archivo `gradle-8.14-bin.zip` y hacen timeout a los 120 segundos. Al ejecutar `./gradlew --version --no-daemon` de forma secuencial primero, el wrapper queda cacheado en `jenkins_home/.gradle/wrapper/dists/` y los builds paralelos lo encuentran disponible inmediatamente.

## 4.6 Variables de entorno del pipeline

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

## 5.7 Árbol de archivos de prueba

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
    service/PushServiceToggleTest.java                      # Unit
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
    integration/QuestionnaireJpaIntegrationTest.java        # Integración

  circleguard-identity-service/src/test/java/com/circleguard/identity/
    controller/IdentityVaultControllerTest.java             # Unit
    util/IdentityEncryptionConverterTest.java               # Unit
    integration/IdentityVaultServiceIntegrationTest.java    # Integración

  circleguard-dashboard-service/src/test/java/com/circleguard/dashboard/
    service/KAnonymityFilterTest.java                       # Unit
    service/AnalyticsServiceTest.java                       # Unit
    integration/AnalyticsControllerIntegrationTest.java     # Integración

  circleguard-file-service/src/test/java/com/circleguard/file/
    controller/FileUploadControllerTest.java                # Unit
    service/FileStorageServiceTest.java                     # Unit
    integration/FileUploadIntegrationTest.java              # Integración

mobile/
  hooks/useQrToken.test.ts                                  # Unit (mobile)
  components/__tests__/DynamicForm.test.tsx                 # Unit (mobile)
  context/__tests__/AuthContext.test.tsx                    # Unit (mobile)
  utils/__tests__/storage.test.ts                           # Unit (mobile)

locust/
  locustfile.py                                             # Rendimiento
  locust.conf                                               # Configuración headless
  Dockerfile                                                # Imagen efímera sin volúmenes

zap/
  run_zap.sh                                                # Script de escaneo ZAP
  rules.tsv                                                 # Reglas de supresión
```

## 5.8 Actualización del pipeline para integrar los nuevos tests

### Sub-etapas de integración (antes vs. después)

Antes de esta entrega, varias sub-etapas de la etapa `Integration Tests` imprimían `echo 'omitida'`. Se habilitaron todas las que no requieren Testcontainers Neo4j (limitación de macOS CI):

| Sub-etapa | Antes | Después |
|---|---|---|
| `integration:file-service` | `echo 'omitida'` | `gradle test --tests "*.file.integration.*"` |
| `integration:gateway-service` | `echo 'omitida'` | `gradle test --tests "*.gateway.integration.*"` |
| `integration:dashboard-service` | `echo 'omitida'` | `gradle test --tests "*.dashboard.integration.*"` |
| `integration:form-service` | `echo 'omitida'` | `gradle test --tests "*.form.integration.*"` |
| `integration:notification-service` | `echo 'omitida'` | `gradle test --tests "*.notification.integration.*"` |
| `integration:identity-service` | *(no existía)* | `gradle test --tests "*.identity.integration.*"` |
| `integration:promotion-service` | `echo 'omitida'` | `echo 'omitida'` (Testcontainers Neo4j — macOS) |

### Nuevos stages añadidos (todos los Jenkinsfiles)

Se añadieron tres nuevos stages a los tres Jenkinsfiles (`dev`, `stage`, `master`):

| Stage nuevo | Posición en el pipeline | Propósito |
|---|---|---|
| `Mobile Tests` | Después de `Integration Tests` | `npm run test:ci` con reporte JUnit XML |
| `Coverage Reports` | Después de `Mobile Tests` | `./gradlew jacocoTestReport` + archiva HTML |
| `Security Tests (OWASP ZAP)` | Solo `Jenkinsfile.master`, post-deploy | `zap/run_zap.sh` contra los 300XX |

## 5.9 Pruebas de Seguridad (OWASP ZAP)

El script `zap/run_zap.sh` ejecuta un escaneo pasivo (sin ataques activos) con OWASP ZAP Baseline contra los 8 microservicios en los NodePorts 300XX de producción. Integrado en el pipeline `Jenkinsfile.master` post-deploy.

| Regla suprimida en `zap/rules.tsv` | Justificación |
|---|---|
| Content Security Policy (10038) | No aplica a APIs REST sin frontend |
| Cookie flags (10012, 10011, 10054) | La API usa JWT Bearer, no cookies de sesión |
| CORS abierto (10098) | Intencional — app móvil Expo consume la API |
| Swagger UI SubResource Integrity (90003) | Falso positivo estructural en APIs con Springdoc |

Las reglas de inyección real (SQL, XSS, XSLT) están marcadas como `FAIL` — bloquean el pipeline si ZAP las detecta.

## 5.10 Imagen Docker de Locust (sin volúmenes)

Para ejecutar Locust en el pipeline Jenkins (Docker-in-Docker en macOS), no es posible montar volúmenes con paths del contenedor Jenkins porque Docker Desktop busca esos paths en el host macOS y no los encuentra. La solución es construir una imagen efímera que embebe los archivos:

```dockerfile
FROM locustio/locust
USER root
COPY . /mnt/locust/
RUN chown -R locust:locust /mnt/locust
USER locust
WORKDIR /mnt/locust
```

`docker build` envía los archivos como un tar al daemon Docker (no como paths del host). El `chown` es necesario porque `COPY` crea los archivos con propietario `root` y Locust necesita escritura para generar los reportes HTML/CSV en ese directorio.

## 5.11 Cómo ejecutar todas las pruebas localmente

```bash
# Backend (todas las pruebas unitarias e integración, excepto Testcontainers Neo4j)
./gradlew test --no-daemon

# Solo unitarias de un servicio
./gradlew :services:circleguard-gateway-service:test --no-daemon

# Solo integración
./gradlew test --tests "*.integration.*" --no-daemon

# Mobile
cd mobile && npm run test:ci

# E2E (requiere entorno dev corriendo en Kubernetes)
E2E_HOST=localhost \
TEST_JWT="<jwt>" \
TEST_ANON_ID="<uuid>" \
TEST_QR_TOKEN="<qr-token>" \
  bash e2e/run_e2e.sh

# Rendimiento (requiere pip install locust)
locust -f locust/locustfile.py --config locust/locust.conf \
  --host http://localhost:31087

# Seguridad ZAP (requiere servicios en 300XX)
bash zap/run_zap.sh
```

## 5.12 Cobertura con JaCoCo y SonarQube

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

## 6.4 Creación del job en Jenkins

El pipeline stage no es detectado automáticamente por el Multibranch Pipeline (que apunta a `Jenkinsfile.dev`). Se crea como un job **Pipeline** independiente apuntando a `Jenkinsfile.stage`:

1. **New Item** → nombre `circleguard-stage-pipeline` → tipo **Pipeline**
2. En **Pipeline** → **Definition**: `Pipeline script from SCM`
3. **SCM**: Git → URL del repositorio
4. **Branch Specifier**: `*/master` (o la rama que corresponda al promote)
5. **Script Path**: `Jenkinsfile.stage`
6. **Save** → **Build Now** para verificar configuración

## 6.5 Resultados de rendimiento por endpoint

El run de referencia ejecutado contra el entorno stage (50 usuarios, 60 s):

| Endpoint | Req. | RPS | Mediana | p95 | p99 | Fallos |
|---|---|---|---|---|---|---|
| `POST /api/v1/gate/validate` | ~720 | ~12 | 3 ms | 8 ms | 15 ms | 0 |
| `GET /api/v1/health/status/{id}` | ~450 | ~7.5 | 4 ms | 10 ms | 20 ms | 0 |
| `POST /api/v1/surveys` | ~180 | ~3 | 5 ms | 12 ms | 25 ms | 0 |
| `GET /api/v1/questionnaires` | ~90 | ~1.5 | 3 ms | 7 ms | 14 ms | 0 |
| `GET /api/v1/analytics/summary` | ~90 | ~1.5 | 5 ms | 13 ms | 28 ms | 0 |
| **Total** | **~1600** | **~28** | **3 ms** | **8 ms** | **17 ms** | **0** |

Los ~518 "fallos" que reporta Locust son respuestas 401/403 de endpoints protegidos correctamente. No representan errores reales del servidor.

## 6.6 Rol del entorno stage como gate pre-producción

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

**Por qué `PREV_TAG` usa `HEAD^`**: `git describe --tags --abbrev=0 HEAD` devolvería el tag del commit actual si ya está tagueado, produciendo un rango vacío (`v1.0.42..v1.0.42`). Usar `HEAD^` garantiza que se busca el tag anterior al commit actual, capturando todos los commits del release.

**`git tag || true`**: el comando `git tag` falla con exit code 128 si el tag ya existe (re-ejecución del pipeline). El `|| true` evita que el pipeline aborte; la lógica de semver garantiza que la versión calculada es siempre única entre builds.

**Limitación**: el tag se crea localmente en el workspace de Jenkins (`git tag vX.Y.Z`). No se hace `git push --tags` al repositorio remoto. En un entorno real, este paso requiere credenciales SSH/HTTPS configuradas en Jenkins para empujar al remote. Las Release Notes generadas (`release-notes-vX.Y.Z.md`) se archivan como artefacto del build.

El tag Git ligero creado en cada release permite:
- `git log v1.0.41..v1.0.42` — ver exactamente qué entró en cada release
- `git checkout v1.0.41` — recrear el estado de cualquier release anterior
- `git describe --tags` — determinar la versión exacta de cualquier build

---

# 8. CI/CD Avanzado

## 8.1 Análisis Estático con SonarQube

SonarQube se levanta con un Compose dedicado:

```bash
docker compose -f sonarqube/docker-compose.sonarqube.yml up -d
# → SonarQube disponible en http://localhost:9000
# → Cambiar contraseña en primer login (admin/admin → nueva contraseña)
# → Crear token en My Account → Security → Generate Token
```

El plugin `org.sonarqube` en `build.gradle.kts` y JaCoCo por subproyecto permiten analizar los 8 servicios en una sola ejecución: `./gradlew sonar`.

### Checklist de configuración en Jenkins

1. **Plugin SonarQube Scanner**: Manage Jenkins → Plugins → SonarQube Scanner → instalar
2. **Plugin Email Extension**: Manage Jenkins → Plugins → Email Extension Plugin → instalar
3. **Servidor SonarQube**: Manage Jenkins → Configure System → SonarQube servers → nombre `sonarqube`, URL `http://host.docker.internal:9000`
4. **Credencial `sonar-token`**: Manage Jenkins → Credentials → Secret Text → ID `sonar-token`, valor = token generado en SonarQube
5. **Configuración SMTP**: Manage Jenkins → Configure System → Extended E-mail Notification → SMTP server `localhost`, puerto `1025` (MailHog)
6. **Webhook SonarQube**: En SonarQube → Administration → Webhooks → URL `http://host.docker.internal:8080/sonarqube-webhook/`

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

## 8.5 Archivos modificados/creados en esta entrega

| Archivo | Tipo | Descripción |
|---|---|---|
| `sonarqube/docker-compose.sonarqube.yml` | Nuevo | SonarQube + PostgreSQL para análisis estático |
| `scripts/semver.sh` | Nuevo | Versionado semántico desde Conventional Commits |
| `Jenkinsfile.security` | Nuevo | Pipeline nocturno (`H 2 * * *`) Trivy + ZAP |
| `Jenkinsfile.dev` | Modificado | +Mobile Tests, +Coverage Reports, +Trivy IaC |
| `Jenkinsfile.stage` | Modificado | +Mobile Tests, +Coverage Reports, +Trivy IaC |
| `Jenkinsfile.master` | Modificado | +Release Notes, +OWASP ZAP, Trivy `exit-code=1` |
| `build.gradle.kts` | Modificado | Plugin `org.sonarqube` + JaCoCo por subproyecto |

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

**Interfaz de `scripts/rollback.sh`**:

```bash
# Rollback del servicio auth al estado anterior
bash scripts/rollback.sh auth-service

# Rollback de todos los servicios a revisión específica
bash scripts/rollback.sh all --to-revision 2

# Re-escalar si post.always dejó réplicas en 0
bash scripts/rollback.sh all --scale-up
```

El script acepta el nombre corto del servicio (sin prefijo `circleguard-`) o `all` para operar sobre los 8 deployments del namespace `circleguard`. El flag `--to-revision N` pasa directamente a `kubectl rollout undo --to-revision`.

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

**Configuración `logback-spring.xml`** (idéntica en los 8 servicios en `src/main/resources/`):

```xml
<configuration>
  <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
    <encoder class="net.logstash.logback.encoder.LogstashEncoder">
      <includeMdcKeyName>traceId</includeMdcKeyName>
      <includeMdcKeyName>spanId</includeMdcKeyName>
      <includeMdcKeyName>parentId</includeMdcKeyName>
    </encoder>
  </appender>
  <root level="INFO">
    <appender-ref ref="JSON"/>
  </root>
</configuration>
```

**Ejemplo de log emitido por `auth-service`**:

```json
{
  "@timestamp": "2024-06-08T14:23:11.234Z",
  "level": "INFO",
  "logger_name": "com.circleguard.auth.controller.LoginController",
  "message": "Login attempt for user: jdoe",
  "traceId": "c4fb6a2e3b1d4f8a",
  "spanId":  "a1b2c3d4e5f6a7b8",
  "service": "circleguard-auth-service"
}
```

El campo `traceId` permite correlacionar este log con la traza en Zipkin: `GET http://localhost:30093/api/v2/trace/c4fb6a2e3b1d4f8a`.

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

## 10.7 Métricas técnicas (automáticas)

Con `micrometer-registry-prometheus`, Spring Boot registra automáticamente:

| Métrica | Descripción |
|---|---|
| `http_server_requests_seconds{uri,method,status}` | Latencia y tasa de peticiones HTTP |
| `jvm_memory_used_bytes{area,id}` | Memoria JVM usada |
| `jvm_memory_max_bytes{area,id}` | Memoria JVM máxima |
| `jvm_threads_live_threads` | Hilos JVM activos |
| `jvm_gc_pause_seconds` | Pausas de Garbage Collector |
| `process_cpu_usage` | CPU del proceso |
| `up` | Estado del scrape target (1=UP, 0=DOWN) |

## 10.8 Métricas de Negocio (Custom Counters)

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

**Consultas PromQL de referencia**:

```promql
# Tasa de logins exitosos por minuto
rate(circleguard_logins_total{result="success"}[5m])

# Encuestas enviadas en la última hora
increase(circleguard_surveys_submitted_total[1h])

# Distribución de estados de salud actualizados hoy
sum by (status) (increase(circleguard_health_status_updates_total[24h]))

# Latencia p99 del gateway (validación QR)
histogram_quantile(0.99, rate(http_server_requests_seconds_bucket{job="gateway-service"}[5m]))
```

## 10.9 Puertos del stack de observabilidad por entorno

| Componente | Dev (31xxx) | Stage (32xxx) | Prod (30xxx) |
|---|---|---|---|
| Prometheus | 31090 | 32090 | 30090 |
| Grafana | 31091 | 32091 | 30091 |
| Kibana | 31092 | 32092 | 30092 |
| Zipkin | 31093 | 32093 | 30093 |
| Alertmanager | 31094 | 32094 | 30094 |

## 10.10 Archivos modificados/creados en esta entrega

| Archivo | Tipo | Descripción |
|---|---|---|
| `services/*/src/main/resources/logback-spring.xml` (×8) | Nuevo | JSON logging con LogstashEncoder + traceId/spanId |
| `k8s/infra/01-configmap.yml` | Modificado | +6 vars `MANAGEMENT_*` para actuator y tracing |
| `k8s/infra/10-prometheus.yml` | Nuevo | Prometheus + reglas de alerta |
| `k8s/infra/11-alertmanager.yml` | Nuevo | Alertmanager → MailHog SMTP |
| `k8s/infra/12-elasticsearch.yml` | Nuevo | Elasticsearch single-node |
| `k8s/infra/13-logstash.yml` | Nuevo | Logstash: beats → Elasticsearch |
| `k8s/infra/14-kibana.yml` | Nuevo | Kibana UI |
| `k8s/infra/15-filebeat.yml` | Nuevo | Filebeat DaemonSet + RBAC |
| `k8s/infra/16-zipkin.yml` | Nuevo | Zipkin in-memory |
| `k8s/infra/17-grafana.yml` | Nuevo | Grafana + dashboards JSON |
| `terraform/modules/k8s-prometheus/` | Nuevo | Módulo Terraform Prometheus |
| `terraform/modules/k8s-grafana/` | Nuevo | Módulo Terraform Grafana |
| `terraform/modules/k8s-elasticsearch/` | Nuevo | Módulo Terraform Elasticsearch |
| `terraform/modules/k8s-logstash/` | Nuevo | Módulo Terraform Logstash |
| `terraform/modules/k8s-kibana/` | Nuevo | Módulo Terraform Kibana |
| `terraform/modules/k8s-filebeat/` | Nuevo | Módulo Terraform Filebeat DaemonSet |
| `terraform/modules/k8s-zipkin/` | Nuevo | Módulo Terraform Zipkin |
| `terraform/modules/k8s-microservice/main.tf` | Modificado | Probes HTTP startup/liveness/readiness |
| `build.gradle.kts` | Modificado | +5 dependencias Micrometer/Zipkin en `subprojects` |

## 10.11 Checklist de validación del stack de observabilidad

```bash
# 1. Todos los pods Running en el namespace
kubectl get pods -n circleguard

# 2. Prometheus scrapea los 8 servicios (todos UP=1)
curl -s 'http://localhost:30090/api/v1/query?query=up' | \
  python3 -c "import sys,json; [print(r['metric']['job'], r['value'][1]) for r in json.load(sys.stdin)['data']['result']]"

# 3. Métricas de negocio disponibles
curl -s http://localhost:30087/actuator/prometheus | grep circleguard_gate

# 4. Health probes responden OK
curl http://localhost:30087/actuator/health/readiness
# → {"status":"UP"}

# 5. Trazas en Zipkin
curl http://localhost:30093/api/v2/services
# → ["circleguard-auth-service","circleguard-gateway-service",...]

# 6. Logs en Elasticsearch
curl http://localhost:30092  # Kibana accesible
```

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

**Código Terraform de las ServiceAccounts**:

```hcl
# terraform/modules/k8s-rbac/main.tf
resource "kubernetes_service_account_v1" "microservices" {
  for_each = toset(var.service_names)
  metadata {
    name      = "${each.key}-sa"
    namespace = var.namespace
  }
  automount_service_account_token = false
}
```

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

**Código Terraform del certificado TLS y del Ingress**:

```hcl
# terraform/modules/k8s-ingress/main.tf
resource "tls_private_key" "circleguard" { algorithm = "RSA"; rsa_bits = 2048 }

resource "tls_self_signed_cert" "circleguard" {
  private_key_pem       = tls_private_key.circleguard.private_key_pem
  subject               { common_name = var.ingress_host; organization = "CircleGuard" }
  dns_names             = [var.ingress_host]
  validity_period_hours = 8760
  allowed_uses          = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "kubernetes_secret_v1" "tls" {
  type = "kubernetes.io/tls"
  data = {
    "tls.crt" = tls_self_signed_cert.circleguard.cert_pem
    "tls.key" = tls_private_key.circleguard.private_key_pem
  }
}

resource "kubernetes_ingress_v1" "gateway" {
  spec {
    ingress_class_name = "nginx"
    tls { hosts = ["circleguard.local"]; secret_name = "circleguard-tls" }
    rule {
      host = var.ingress_host
      http { path { path = "/()(.*)"
        backend { service { name = "gateway-service-svc"; port { number = 8087 } } }
      } }
    }
  }
}
```

**NodePorts HTTPS por entorno**:

| Entorno | NodePort HTTPS | URL |
|---|---|---|
| Producción (`circleguard`) | 30443 | `https://circleguard.local:30443` |
| Dev (`circleguard-dev`) | 31443 | `https://circleguard.local:31443` |
| Stage (`circleguard-stage`) | 32443 | `https://circleguard.local:32443` |

```bash
# Probar TLS local (acepta cert self-signed)
echo "127.0.0.1 circleguard.local" | sudo tee -a /etc/hosts
curl -k -H 'Host: circleguard.local' https://localhost:31443/
```

## 11.5 Archivos modificados/creados en esta entrega

| Archivo | Tipo | Descripción |
|---|---|---|
| `k8s/infra/18-rbac.yml` | Nuevo | 8 ServiceAccounts + 2 Roles + RoleBindings |
| `k8s/infra/19-ingress.yml` | Nuevo | ingress-nginx NodePort + Secret TLS + Ingress HTTPS |
| `terraform/modules/k8s-rbac/` | Nuevo | Módulo Terraform: SA, Roles, RoleBindings |
| `terraform/modules/k8s-ingress/` | Nuevo | Módulo Terraform: ingress-nginx Helm + cert TLS + Ingress |
| `terraform/envs/{dev,stage,prod}/main.tf` | Modificado | +módulos `k8s-rbac` y `k8s-ingress` |
| `Jenkinsfile.security` | Nuevo | Pipeline cron nocturno `H 2 * * *`: Trivy imagen + IaC |
| `Jenkinsfile.dev` | Modificado | +stage `Trivy IaC Scan` (`exit-code=0`) |
| `Jenkinsfile.stage` | Modificado | +stage `Trivy IaC Scan` (`exit-code=0`) |
| `Jenkinsfile.master` | Modificado | +stage `Trivy IaC Scan` (`exit-code=1` bloquea) |
| `.trivyignore` | Nuevo | CVEs aceptados con comentarios de justificación |
| `k8s/services/15-auth-service.yml` | Modificado | `serviceAccountName: auth-service-sa` |
| `k8s/services/16-identity-service.yml` | Modificado | `serviceAccountName: identity-service-sa` |
| `terraform/envs/{dev,stage,prod}/main.tf` | Modificado | Secretos LDAP/Vault eliminados del `extra_env` inline |

## 11.6 Checklist de validación de seguridad

```bash
# 1. ServiceAccounts creadas (sin automount)
kubectl get sa -n circleguard | grep -E "auth|identity|gateway|form|file|dashboard|notification|promotion"

# 2. Roles creados
kubectl get role -n circleguard

# 3. TLS activo en ingress
echo "127.0.0.1 circleguard.local" >> /etc/hosts
curl -k -s -o /dev/null -w "%{http_code}" https://circleguard.local:30443/
# → 200, 401, 403 (no 000)

# 4. Trivy sin HIGH/CRITICAL no documentados
cat .trivyignore

# 5. Secretos no expuestos en texto plano en manifests de servicio
kubectl get deployment circleguard-auth-service -n circleguard -o yaml | grep -i password
# → solo referencias a secretRef, no valores en texto plano
```

---

# 12. Costos de Infraestructura

## 12.1 Entorno actual: costo $0

El entorno de desarrollo usa Docker Desktop con LocalStack. Costo operativo en desarrollo: **$0**.

## 12.2 Recursos por microservicio

| Servicio | Réplicas | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|---|
| auth-service | 1 | 100m | 500m | 256Mi | 512Mi |
| identity-service | 1 | 100m | 500m | 256Mi | 512Mi |
| file-service | 1 | 100m | 500m | 256Mi | 512Mi |
| gateway-service | 1 | 100m | 500m | 256Mi | 512Mi |
| dashboard-service | 1 | 100m | 500m | 256Mi | 512Mi |
| form-service | 1 | 100m | 500m | 256Mi | 512Mi |
| notification-service | 1 | 100m | 500m | 256Mi | 512Mi |
| promotion-service | 1 | 500m | 2000m | 1024Mi | 2048Mi |

`promotion-service` es más intensivo: mantiene el grafo Neo4j de contactos en memoria y procesa eventos Kafka en tiempo real.

**Subtotal microservicios**: ~1.3 vCPU requests, ~3.75 Gi RAM requests.

## 12.3 Recursos del stack de observabilidad

| Componente | Réplicas | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|---|
| Elasticsearch | 1 | 200m | 1000m | 1024Mi | 2048Mi |
| Logstash | 1 | 100m | 500m | 256Mi | 512Mi |
| Kibana | 1 | 100m | 500m | 256Mi | 512Mi |
| Filebeat (DaemonSet) | 1/nodo | 100m | 500m | 256Mi | 512Mi |
| Prometheus | 1 | 100m | 500m | 256Mi | 512Mi |
| Grafana | 1 | 100m | 500m | 128Mi | 256Mi |
| Zipkin | 1 | 100m | 500m | 256Mi | 512Mi |
| Alertmanager | 1 | 100m | 200m | 128Mi | 256Mi |

**Subtotal observabilidad**: ~1.0 vCPU requests, ~2.6 Gi RAM requests.

## 12.4 Recursos de infraestructura de datos

| Componente | Réplicas | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|---|
| PostgreSQL | 1 | 250m | 500m | 256Mi | 512Mi |
| Neo4j | 1 | 500m | 1000m | 512Mi | 1024Mi |
| Kafka | 1 | 250m | 500m | 512Mi | 1024Mi |
| Zookeeper | 1 | 100m | 200m | 256Mi | 512Mi |
| Redis | 1 | 100m | 200m | 128Mi | 256Mi |
| OpenLDAP | 1 | 100m | 200m | 128Mi | 256Mi |

**Subtotal datos**: ~1.3 vCPU requests, ~1.8 Gi RAM requests.

## 12.5 Totales del clúster (recursos Kubernetes)

| Capa | CPU requests | RAM requests |
|---|---|---|
| Microservicios (8) | ~1.3 vCPU | ~3.75 Gi |
| Observabilidad (8 componentes) | ~1.0 vCPU | ~2.6 Gi |
| Infraestructura de datos (6 componentes) | ~1.3 vCPU | ~1.8 Gi |
| **Total** | **~3.6 vCPU** | **~8.15 Gi** |

## 12.6 Estimación en AWS (us-east-1, precios aprox. junio 2026)

| Opción | Configuración | Precio/mes |
|---|---|---|
| **A — Nodo único** | EC2 t3.2xlarge (8 vCPU, 32 Gi) + EKS + storage + bandwidth | ~$326 |
| **B — Multi-nodo prod** | 4 EC2 t3.xlarge/large + EKS + storage + S3 + Secrets Manager | ~$515 |
| **C — Desarrollo local** | Docker Desktop + LocalStack | **$0** |

## 12.7 Optimizaciones de costo

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

---

# Video de Demostración

https://youtu.be/3Z8f4QA5kFA
