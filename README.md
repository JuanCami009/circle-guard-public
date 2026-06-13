# CircleGuard - Taller 2: Pruebas y Lanzamiento

**Video de evidencia (Taller 2):** https://youtu.be/D9iUHjesDdI

**Video de evidencia (Proyecto Final):** https://youtu.be/3Z8f4QA5kFA

---

## Resumen por Punto

### [Punto 1 - Configuración de Jenkins, Docker y Kubernetes (10%)](docs/01-punto1-configuracion.md)

Se configuró el entorno de CI/CD completo desde cero. Jenkins se levanta como contenedor Docker con una imagen personalizada (`jenkins/Dockerfile`) que incluye los binarios de `docker` y `kubectl` para poder construir imágenes y desplegar en Kubernetes desde dentro del pipeline. Se configuró como Multibranch Pipeline apuntando al repositorio. Kubernetes corre en Docker Desktop. Se seleccionaron 6 microservicios interconectados: `file-service`, `gateway-service`, `dashboard-service`, `form-service`, `notification-service` y `promotion-service`.

### [Punto 2 - Pipeline Dev Environment (15%)](docs/02-punto2-pipeline-dev.md)

Se implementó `Jenkinsfile.dev` con 10 etapas: checkout, prepare, build JARs (paralelo), unit tests (paralelo), integration tests (paralelo), Docker build con tag `:dev` (paralelo), deploy al namespace `circleguard-dev`, smoke tests via `curl`, y placeholders para E2E y performance. Los manifests de Kubernetes existentes se reutilizan con transformaciones `sed` para adaptar namespace, tag de imagen y NodePorts al rango `310XX`.

### [Punto 3 - Pruebas: Unitarias, Integración, E2E y Rendimiento (30%)](docs/03-punto3-pruebas.md)

Se implementaron 4 niveles de prueba:

- **5 pruebas unitarias**: `GraphCleanupTaskTest`, `LocationResolutionServiceTest` (promotion), `JwtTokenServiceTest`, `QrTokenServiceTest` (auth), `AuditLogServiceTest` (notification). Sin Spring context, usando Mockito puro.
- **5 pruebas de integración**: `SurveyListenerIntegrationTest` (promotion+Kafka), `ExposureNotificationIntegrationTest` (notification), `GatewayValidationIntegrationTest` (gateway), `QuestionnaireJpaIntegrationTest` (form), `IdentityVaultServiceIntegrationTest` (identity). Usan `@SpringBootTest` + Testcontainers.
- **5 flujos E2E**: script `e2e/run_e2e.sh` parametrizable por variables de entorno (`E2E_PORT_*`), cubre registro de archivo, validación de gateway, envío de formulario, notificación y consulta de dashboard.
- **Pruebas de rendimiento**: `locust/locustfile.py` con 4 escenarios (promotion, form, gateway, dashboard), parametrizable via `LOCUST_HOST_*`. Incluye análisis de resultados y reporte HTML.

### [Punto 4 - Pipeline Stage Environment (15%)](docs/04-punto4-stage.md)

Se implementó `Jenkinsfile.stage` replicando la estructura del pipeline dev con tres cambios de eje: namespace `circleguard-stage`, tag `:stage`, NodePorts `320XX`. A diferencia del pipeline dev, las etapas de E2E y performance son funcionales (no placeholders): `run_e2e.sh` y `locustfile.py` reciben las variables de entorno apuntando al rango `320XX`. Todos los manifests se transforman con `sed` igual que en dev.

### [Punto 5 - Pipeline Master/Producción (15%)](docs/05-punto5-master.md)

Se implementó `Jenkinsfile.master` para despliegue en el namespace canónico `circleguard`. A diferencia de dev y stage, **no aplica transformaciones `sed`**: los manifests ya tienen namespace `circleguard`, tag `:latest` y NodePorts `300XX`. Se agregó la etapa **Release Notes** (etapa 11): genera un artefacto Markdown clasificando commits por tipo (Conventional Commits), incluye metadata del build y crea un tag Git ligero para marcar el release en el historial. Al finalizar el pipeline, los deployments se escalan a cero (`kubectl scale --replicas=0`) para conservar recursos del clúster local.

### Punto 6 - Documentación y Video (15%) - [docs/](docs/)

Documentación completa en `docs/` con un archivo por punto. Video de evidencia en https://youtu.be/D9iUHjesDdI mostrando ejecución de los pipelines dev, stage y master, resultados de pruebas y generación de release notes.

### [Punto 6 (Proyecto Final) - Change Management y Release Notes (5%)](docs/08-punto6-change-management.md)

Implementación del proceso formal de Change Management sobre GitFlow y el pipeline de Jenkins. Incluye: (1) generación automática de Release Notes en `Jenkinsfile.master` (stage `Release Notes`, línea 622) clasificando commits por Conventional Commits; (2) versionado semántico automático con `scripts/semver.sh` y etiquetado git `vX.Y.Z`; (3) proceso ITIL ligero con tipos de cambio (Standard/Normal/Emergency), roles y flujo completo de aprobación mapeado a las etapas reales del pipeline; (4) planes de rollback por escenario (rollout undo K8s y rollback por versión git) con script ejecutable `scripts/rollback.sh`.

### [Punto 7 (Proyecto Final) - Observabilidad y Monitoreo (10%)](docs/09-punto7-observabilidad.md)

Implementación completa del stack de observabilidad sobre los 8 microservicios Spring Boot. Incluye: (1) **Prometheus + Grafana** con dashboards por servicio (variable `$service`) y dashboard de métricas de negocio provisionados automáticamente vía ConfigMap; (2) **ELK Stack** (Elasticsearch 8.13 + Logstash + Kibana + Filebeat DaemonSet) con logs JSON via `LogstashEncoder` + trazas correladas por `traceId`; (3) **Alertas**  - 5 reglas en Prometheus (`ServiceDown`, `HighErrorRate`, `HighLatencyP99`, `HighJvmHeapUsage`, `NoHealthStatusUpdates`) → Alertmanager → MailHog SMTP; (4) **Tracing distribuido** con Zipkin y `micrometer-tracing-bridge-brave` (100% sampling, headers B3); (5) **Health probes HTTP** (`startupProbe` + `livenessProbe` + `readinessProbe` en `/actuator/health/liveness|readiness`) en todos los manifests K8s y módulo Terraform genérico; (6) **Métricas de negocio** custom con Micrometer Counters en 4 servicios (logins, surveys, status updates, notifications). Módulos Terraform en `terraform/modules/k8s-{prometheus,grafana,elasticsearch,logstash,kibana,filebeat,zipkin,alertmanager}/` y manifests estáticos en `k8s/infra/10-17-*.yml`.

### [Punto 8 (Proyecto Final) - Seguridad (5%)](docs/10-punto8-seguridad.md)

Implementación completa de las cuatro capacidades de seguridad sobre la arquitectura CircleGuard. Incluye: (1) **Escaneo continuo de vulnerabilidades** con Trivy en dos modos  - `image` (8 imágenes Docker, existente desde Punto 4) y `config` (IaC/misconfig sobre `k8s/` y `terraform/`) añadido a los tres Jenkinsfiles + `Jenkinsfile.security` con cron diario nocturno (`H 2 * * *`) y notificación por email; (2) **Gestión segura de secretos** vía AWS Secrets Manager (LocalStack) → `circleguard-secrets` K8s Secret → `envFrom`  - se eliminaron los secretos inline de `auth-service` (`SPRING_LDAP_PASSWORD`) e `identity-service` (`VAULT_SECRET/SALT/HASH_SALT`) que evadían el Secret; (3) **RBAC**  - ServiceAccount dedicada por microservicio con `automountServiceAccountToken: false` + Roles namespaced `circleguard-developer` (read-only) y `circleguard-ci-deployer` (deploy) en módulo `k8s-rbac/` y manifest `18-rbac.yml`; (4) **TLS**  - ingress-nginx vía Helm + certificado self-signed generado por `hashicorp/tls` + Ingress HTTPS `circleguard.local → gateway-service` en módulo `k8s-ingress/` y manifest `19-ingress.yml`, puertos `30443/31443/32443` por ambiente.

---

## Documentacion

| Archivo | Descripcion |
|:---|:---|
| [`docs/01-punto1-configuracion.md`](docs/01-punto1-configuracion.md) | Configuracion de Jenkins, Docker y Kubernetes (Punto 1) |
| [`docs/02-punto2-pipeline-dev.md`](docs/02-punto2-pipeline-dev.md) | Pipeline de desarrollo con 10 etapas (Punto 2) |
| [`docs/03-punto3-pruebas.md`](docs/03-punto3-pruebas.md) | Pruebas unitarias, integracion, E2E y rendimiento (Punto 3) |
| [`docs/04-punto4-stage.md`](docs/04-punto4-stage.md) | Pipeline de stage con Terraform y namespace circleguard-stage (Punto 4) |
| [`docs/05-punto5-master.md`](docs/05-punto5-master.md) | Pipeline de produccion con Release Notes y aprobacion manual (Punto 5) |
| [`docs/06-patrones-diseno.md`](docs/06-patrones-diseno.md) | Patrones de diseno identificados e implementados (Proyecto Final) |
| [`docs/07-punto4-cicd-avanzado.md`](docs/07-punto4-cicd-avanzado.md) | CI/CD avanzado: SonarQube, Trivy, versionado semantico (Proyecto Final) |
| [`docs/08-punto6-change-management.md`](docs/08-punto6-change-management.md) | Change Management, Release Notes y rollback (Punto 6 Proyecto Final) |
| [`docs/09-punto7-observabilidad.md`](docs/09-punto7-observabilidad.md) | Observabilidad: Prometheus, Grafana, ELK, Zipkin (Punto 7 Proyecto Final) |
| [`docs/10-punto8-seguridad.md`](docs/10-punto8-seguridad.md) | Seguridad: Trivy, secretos, RBAC, TLS (Punto 8 Proyecto Final) |
| [`docs/11-costos-infraestructura.md`](docs/11-costos-infraestructura.md) | Estimacion de costos en AWS vs entorno local |
| [`docs/12-manual-operaciones.md`](docs/12-manual-operaciones.md) | Manual de operaciones: accesos, despliegue, rollback, troubleshooting |
| [`InformeFinal.md`](InformeFinal.md) | Informe final consolidado del Proyecto Final |

---

## Microservicios Seleccionados

| Servicio | Puerto prod | Puerto dev | Puerto stage |
|:---|:---:|:---:|:---:|
| notification-service | 30082 | 31082 | 32082 |
| dashboard-service | 30084 | 31084 | 32084 |
| file-service | 30085 | 31085 | 32085 |
| form-service | 30086 | 31086 | 32086 |
| gateway-service | 30087 | 31087 | 32087 |
| promotion-service | 30088 | 31088 | 32088 |

---

## Stack Tecnológico

| Capa | Tecnología |
|:---|:---|
| Backend | Spring Boot / Java 21 |
| Graph DB | Neo4j 5.26 |
| Relational DB | PostgreSQL 16 |
| Message Bus | Apache Kafka |
| Caching | Redis 7.2 |
| CI/CD | Jenkins (Multibranch Pipeline) |
| Contenedores | Docker |
| Orquestación | Kubernetes (Docker Desktop) |
| Pruebas backend | JUnit 5 + Mockito + Testcontainers |
| Pruebas E2E | Bash + curl |
| Pruebas rendimiento | Locust |
| Mobile | Expo (React Native) |
