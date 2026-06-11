# CircleGuard - Taller 2: Pruebas y Lanzamiento

**Video de evidencia:** https://youtu.be/D9iUHjesDdI

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

Implementación completa del stack de observabilidad sobre los 8 microservicios Spring Boot. Incluye: (1) **Prometheus + Grafana** con dashboards por servicio (variable `$service`) y dashboard de métricas de negocio provisionados automáticamente vía ConfigMap; (2) **ELK Stack** (Elasticsearch 8.13 + Logstash + Kibana + Filebeat DaemonSet) con logs JSON via `LogstashEncoder` + trazas correladas por `traceId`; (3) **Alertas** — 5 reglas en Prometheus (`ServiceDown`, `HighErrorRate`, `HighLatencyP99`, `HighJvmHeapUsage`, `NoHealthStatusUpdates`) → Alertmanager → MailHog SMTP; (4) **Tracing distribuido** con Zipkin y `micrometer-tracing-bridge-brave` (100% sampling, headers B3); (5) **Health probes HTTP** (`startupProbe` + `livenessProbe` + `readinessProbe` en `/actuator/health/liveness|readiness`) en todos los manifests K8s y módulo Terraform genérico; (6) **Métricas de negocio** custom con Micrometer Counters en 4 servicios (logins, surveys, status updates, notifications). Módulos Terraform en `terraform/modules/k8s-{prometheus,grafana,elasticsearch,logstash,kibana,filebeat,zipkin,alertmanager}/` y manifests estáticos en `k8s/infra/10-17-*.yml`.

### [Punto 8 (Proyecto Final) - Seguridad (5%)](docs/10-punto8-seguridad.md)

Implementación completa de las cuatro capacidades de seguridad sobre la arquitectura CircleGuard. Incluye: (1) **Escaneo continuo de vulnerabilidades** con Trivy en dos modos — `image` (8 imágenes Docker, existente desde Punto 4) y `config` (IaC/misconfig sobre `k8s/` y `terraform/`) añadido a los tres Jenkinsfiles + `Jenkinsfile.security` con cron diario nocturno (`H 2 * * *`) y notificación por email; (2) **Gestión segura de secretos** vía AWS Secrets Manager (LocalStack) → `circleguard-secrets` K8s Secret → `envFrom` — se eliminaron los secretos inline de `auth-service` (`SPRING_LDAP_PASSWORD`) e `identity-service` (`VAULT_SECRET/SALT/HASH_SALT`) que evadían el Secret; (3) **RBAC** — ServiceAccount dedicada por microservicio con `automountServiceAccountToken: false` + Roles namespaced `circleguard-developer` (read-only) y `circleguard-ci-deployer` (deploy) en módulo `k8s-rbac/` y manifest `18-rbac.yml`; (4) **TLS** — ingress-nginx vía Helm + certificado self-signed generado por `hashicorp/tls` + Ingress HTTPS `circleguard.local → gateway-service` en módulo `k8s-ingress/` y manifest `19-ingress.yml`, puertos `30443/31443/32443` por ambiente.

---

## Archivos por Punto

Archivo / Ruta | Descripción |
:---|:---|
| [`docs/01-punto1-configuracion.md`](docs/01-punto1-configuracion.md) | Documentación Punto 1 |
| [`docs/02-punto2-pipeline-dev.md`](docs/02-punto2-pipeline-dev.md) | Documentación Punto 2 |
| [`docs/03-punto3-pruebas.md`](docs/03-punto3-pruebas.md) | Documentación Punto 3 |
| [`docs/04-punto4-stage.md`](docs/04-punto4-stage.md) | Documentación Punto 4 |
| [`docs/05-punto5-master.md`](docs/05-punto5-master.md) | Documentación Punto 5 |
| [`docs/08-punto6-change-management.md`](docs/08-punto6-change-management.md) | Change Management y Release Notes (Punto 6 Proyecto Final) |
| [`docs/09-punto7-observabilidad.md`](docs/09-punto7-observabilidad.md) | Observabilidad y Monitoreo (Punto 7 Proyecto Final) |
| [`scripts/rollback.sh`](scripts/rollback.sh) | Script de rollback de deployments K8s |
| [`scripts/semver.sh`](scripts/semver.sh) | Versionado semántico automático (Conventional Commits) |
| [`CHANGELOG.md`](CHANGELOG.md) | Historial consolidado de releases (Keep a Changelog) |
| [`terraform/modules/k8s-prometheus/`](terraform/modules/k8s-prometheus/) | Módulo Terraform — Prometheus + alert rules |
| [`terraform/modules/k8s-grafana/`](terraform/modules/k8s-grafana/) | Módulo Terraform — Grafana + dashboards |
| [`terraform/modules/k8s-elasticsearch/`](terraform/modules/k8s-elasticsearch/) | Módulo Terraform — Elasticsearch 8.13 |
| [`terraform/modules/k8s-logstash/`](terraform/modules/k8s-logstash/) | Módulo Terraform — Logstash (beats→ES) |
| [`terraform/modules/k8s-kibana/`](terraform/modules/k8s-kibana/) | Módulo Terraform — Kibana |
| [`terraform/modules/k8s-filebeat/`](terraform/modules/k8s-filebeat/) | Módulo Terraform — Filebeat DaemonSet + RBAC |
| [`terraform/modules/k8s-zipkin/`](terraform/modules/k8s-zipkin/) | Módulo Terraform — Zipkin |
| [`terraform/modules/k8s-alertmanager/`](terraform/modules/k8s-alertmanager/) | Módulo Terraform — Alertmanager → MailHog |
| [`k8s/infra/10-prometheus.yml`](k8s/infra/10-prometheus.yml) | Manifest estático — Prometheus |
| [`k8s/infra/11-alertmanager.yml`](k8s/infra/11-alertmanager.yml) | Manifest estático — Alertmanager |
| [`k8s/infra/12-elasticsearch.yml`](k8s/infra/12-elasticsearch.yml) | Manifest estático — Elasticsearch |
| [`k8s/infra/13-logstash.yml`](k8s/infra/13-logstash.yml) | Manifest estático — Logstash |
| [`k8s/infra/14-kibana.yml`](k8s/infra/14-kibana.yml) | Manifest estático — Kibana |
| [`k8s/infra/15-filebeat.yml`](k8s/infra/15-filebeat.yml) | Manifest estático — Filebeat |
| [`k8s/infra/16-zipkin.yml`](k8s/infra/16-zipkin.yml) | Manifest estático — Zipkin |
| [`k8s/infra/17-grafana.yml`](k8s/infra/17-grafana.yml) | Manifest estático — Grafana |
| [`docs/10-punto8-seguridad.md`](docs/10-punto8-seguridad.md) | Seguridad (Punto 8 Proyecto Final) |
| [`terraform/modules/k8s-rbac/`](terraform/modules/k8s-rbac/) | Módulo Terraform — RBAC: SAs por servicio + Roles developer/ci-deployer |
| [`terraform/modules/k8s-ingress/`](terraform/modules/k8s-ingress/) | Módulo Terraform — ingress-nginx + TLS self-signed + Ingress |
| [`k8s/infra/18-rbac.yml`](k8s/infra/18-rbac.yml) | Manifest estático — RBAC (ServiceAccounts, Roles, RoleBindings) |
| [`k8s/infra/19-ingress.yml`](k8s/infra/19-ingress.yml) | Manifest estático — Secret TLS + Ingress HTTPS |
| [`Jenkinsfile.security`](Jenkinsfile.security) | Pipeline cron — escaneo continuo Trivy (imágenes + IaC) |

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
