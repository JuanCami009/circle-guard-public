# CircleGuard

**Video de evidencia (Proyecto Final):** https://youtu.be/3Z8f4QA5kFA

---

Plataforma de microservicios para gestión de alertas de salud pública, construida con Spring Boot y desplegada en Kubernetes mediante pipelines Jenkins.

## Arquitectura

8 microservicios Spring Boot que se comunican vía Kafka y HTTP:

| Servicio | Responsabilidad |
|:---|:---|
| `auth-service` | Autenticación JWT + LDAP |
| `identity-service` | Gestión de identidades y vault |
| `gateway-service` | API Gateway y validación de tokens |
| `file-service` | Ingesta y registro de archivos |
| `form-service` | Cuestionarios y formularios |
| `notification-service` | Notificaciones por eventos Kafka |
| `promotion-service` | Propagación en grafo de contactos |
| `dashboard-service` | Consultas y métricas agregadas |

## Stack

| Capa | Tecnología |
|:---|:---|
| Backend | Spring Boot / Java 21 |
| Graph DB | Neo4j 5.26 |
| Relational DB | PostgreSQL 16 |
| Message Bus | Apache Kafka |
| Auth | OpenLDAP |
| Caching | Redis 7.2 |
| CI/CD | Jenkins (Multibranch Pipeline) |
| Contenedores | Docker |
| Orquestación | Kubernetes (Docker Desktop) |
| IaC | Terraform |
| Observabilidad | Prometheus + Grafana + ELK + Zipkin |
| Seguridad | Trivy + AWS Secrets Manager (LocalStack) + RBAC + TLS |
| Mobile | Expo (React Native) |

## Desarrollo local

Levantar infraestructura:

```bash
docker compose up -d
```

Correr un servicio:

```bash
./gradlew :services:circleguard-auth-service:bootRun
```

Servicios de infraestructura disponibles tras `docker compose up`:

| Servicio | URL |
|:---|:---|
| PostgreSQL | `localhost:5432` |
| Neo4j Browser | `http://localhost:7474` |
| Kafka | `localhost:9092` |
| Redis | `localhost:6379` |
| OpenLDAP | `localhost:389` |
| MailHog (UI) | `http://localhost:8025` |

## Pipelines CI/CD

Tres pipelines Jenkins para tres ambientes, cada uno con su propio namespace K8s y rango de NodePorts:

| Pipeline | Namespace | NodePorts | Tag imagen |
|:---|:---|:---:|:---|
| `Jenkinsfile.dev` | `circleguard-dev` | `310XX` | `:dev` |
| `Jenkinsfile.stage` | `circleguard-stage` | `320XX` | `:stage` |
| `Jenkinsfile.master` | `circleguard` | `300XX` | `:latest` |

El pipeline master genera Release Notes automáticas (Conventional Commits) y etiqueta el commit con versión semántica `vX.Y.Z`.

### Puertos de microservicios

| Servicio | Prod | Dev | Stage |
|:---|:---:|:---:|:---:|
| notification-service | 30082 | 31082 | 32082 |
| dashboard-service | 30084 | 31084 | 32084 |
| file-service | 30085 | 31085 | 32085 |
| form-service | 30086 | 31086 | 32086 |
| gateway-service | 30087 | 31087 | 32087 |
| promotion-service | 30088 | 31088 | 32088 |

## Observabilidad

Stack completo provisionado vía Terraform (`terraform/modules/`) y manifests estáticos (`k8s/infra/`):

- **Métricas**: Prometheus + Grafana (dashboards por servicio + métricas de negocio)
- **Logs**: ELK Stack con Filebeat DaemonSet, logs JSON correlados por `traceId`
- **Trazas**: Zipkin con sampling 100% vía Micrometer Brave
- **Alertas**: 5 reglas Prometheus → Alertmanager → MailHog

## Seguridad

- Escaneo de vulnerabilidades con Trivy (`image` + `config`) en cada pipeline
- Secretos gestionados vía AWS Secrets Manager (LocalStack) → K8s Secrets
- RBAC con ServiceAccounts por microservicio y roles namespaced
- TLS con ingress-nginx y certificado auto-firmado (`circleguard.local`)

## Documentación

| Archivo | Descripción |
|:---|:---|
| [`docs/01-punto1-configuracion.md`](docs/01-punto1-configuracion.md) | Configuración Jenkins, Docker y Kubernetes |
| [`docs/02-punto2-pipeline-dev.md`](docs/02-punto2-pipeline-dev.md) | Pipeline de desarrollo |
| [`docs/03-punto3-pruebas.md`](docs/03-punto3-pruebas.md) | Pruebas unitarias, integración, E2E y rendimiento |
| [`docs/04-punto4-stage.md`](docs/04-punto4-stage.md) | Pipeline de stage |
| [`docs/05-punto5-master.md`](docs/05-punto5-master.md) | Pipeline de producción y Release Notes |
| [`docs/06-patrones-diseno.md`](docs/06-patrones-diseno.md) | Patrones de diseño |
| [`docs/07-punto4-cicd-avanzado.md`](docs/07-punto4-cicd-avanzado.md) | CI/CD avanzado: SonarQube, Trivy, versionado |
| [`docs/08-punto6-change-management.md`](docs/08-punto6-change-management.md) | Change Management y rollback |
| [`docs/09-punto7-observabilidad.md`](docs/09-punto7-observabilidad.md) | Observabilidad: Prometheus, Grafana, ELK, Zipkin |
| [`docs/10-punto8-seguridad.md`](docs/10-punto8-seguridad.md) | Seguridad: Trivy, secretos, RBAC, TLS |
| [`docs/11-costos-infraestructura.md`](docs/11-costos-infraestructura.md) | Estimación de costos AWS vs local |
| [`docs/12-manual-operaciones.md`](docs/12-manual-operaciones.md) | Manual de operaciones y troubleshooting |
