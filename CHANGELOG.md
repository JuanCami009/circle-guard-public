# Changelog

Todos los cambios notables de CircleGuard se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es/1.1.0/),
y el versionado sigue [Semantic Versioning](https://semver.org/lang/es/).

> **Nota:** Las Release Notes detalladas por versión (con metadata de build, commits clasificados
> y tabla de servicios) son generadas automáticamente por el pipeline en `Jenkinsfile.master`
> (stage `Release Notes`) y archivadas como artefactos en Jenkins. Este CHANGELOG es el índice
> consolidado legible por humanos.

---

## [Unreleased]

### Added

- Seguridad completa (Punto 8 Proyecto Final):
  - RBAC: ServiceAccounts dedicadas por microservicio (`automountServiceAccountToken: false`).
  - RBAC: Roles namespaced `circleguard-developer` (read-only) y `circleguard-ci-deployer` (deploy).
  - Módulo Terraform `k8s-rbac/` y manifest estático `k8s/infra/18-rbac.yml`.
  - TLS: ingress-nginx vía Helm + certificado self-signed (`hashicorp/tls`) + Ingress HTTPS.
  - Módulo Terraform `k8s-ingress/` y manifest estático `k8s/infra/19-ingress.yml`.
  - Trivy IaC Scan (stage nuevo en los 3 Jenkinsfiles): misconfig sobre `k8s/` y `terraform/`.
  - `Jenkinsfile.security`: pipeline cron diario (H 2 * * *) — Trivy image + IaC + notificación email.
  - `SPRING_LDAP_PASSWORD` añadida al `circleguard-secrets` K8s Secret y módulo `k8s-config`.

### Changed

- `terraform/envs/{dev,stage,prod}/main.tf`: eliminados secretos inline de auth/identity (`SPRING_LDAP_PASSWORD`, `VAULT_SECRET/SALT/HASH_SALT`), ahora vienen del Secret vía `envFrom`.
- `k8s/services/15-auth-service.yml`: añade SA + elimina `SPRING_LDAP_PASSWORD` inline.
- `k8s/services/16-identity-service.yml`: añade SA + elimina `VAULT_*` inline.
- `terraform/modules/k8s-microservice/`: nuevas variables `service_account_name` y `automount_service_account_token`.
- `terraform/envs/{dev,stage,prod}/providers.tf`: añade provider `hashicorp/tls ~>4`.

---

## [0.7.0] — 2026-06-08

### Added

- Observabilidad completa (Punto 7 Proyecto Final): Prometheus + Grafana + ELK + Zipkin + health probes + métricas de negocio.

---

## [Unreleased — pre-0.7.0]

### Added

- Proceso formal de Change Management (marco ITIL ligero, tipos Standard/Normal/Emergency).
- Planes de rollback documentados con tabla de escenarios y comandos exactos.
- Script `scripts/rollback.sh` para revertir deployments de Kubernetes.
- `CHANGELOG.md` como índice consolidado de releases (este archivo).
- Documentación `docs/08-punto6-change-management.md`.

---

## [0.5.0] — 2026-06-08

### Added

- Pruebas completas (Punto 5 Proyecto Final):
  - Coverage Reports con JaCoCo (backend) y jest (mobile).
  - Mobile Tests con React Native / Expo en Jenkins.
  - Stage OWASP ZAP en `Jenkinsfile.master` para análisis de seguridad de los 8 servicios.
  - Análisis completo de pruebas documentado en `docs/PRUEBAS.md`.

### Changed

- `Jenkinsfile.master`, `Jenkinsfile.stage`, `Jenkinsfile.dev`: integración de cobertura, tests móviles y ZAP.

---

## [0.4.0] — 2026-05-27

### Added

- CI/CD Avanzado (Punto 4 Proyecto Final):
  - SonarQube Analysis + Quality Gate bloqueante en producción.
  - Trivy Scan de vulnerabilidades bloqueante en producción (`HIGH`/`CRITICAL`).
  - Versionado semántico automático (`scripts/semver.sh`, Conventional Commits).
  - Stage `Release Notes` en `Jenkinsfile.master`: genera artefacto Markdown y tag Git `vX.Y.Z`.
  - Notificaciones de fallo/unstable vía MailHog (`emailext`).
  - Stage `Approval (Prod)` con `input` de Jenkins antes del despliegue a producción.
  - Documentación en `docs/07-punto4-cicd-avanzado.md`.

---

## [0.3.0] — 2026-05-26

### Added

- Patrones de diseño (Punto 3 Proyecto Final):
  - Circuit Breaker y Retry con Resilience4j en `gateway-service`.
  - Cache-Aside con Caffeine en `gateway-service`.
  - External Configuration: secretos JWT/QR externalizados con variables de entorno.
  - Feature Toggle con Spring profiles.
  - Documentación con ADRs en `docs/06-patrones-diseno.md`.

---

## [0.2.0] — 2026-05-25

### Added

- Pipeline Stage Environment (`Jenkinsfile.stage`):
  - Namespace `circleguard-stage`, tag `:stage`, NodePorts `320XX`.
  - E2E Tests funcionales (no placeholder) apuntando a puertos `320XX`.
  - Pruebas de rendimiento con Locust apuntando a puertos `320XX`.
  - Documentación en `docs/04-punto4-stage.md`.
- Pipeline Master/Producción (`Jenkinsfile.master`):
  - Namespace canónico `circleguard`, tag `:latest`, NodePorts `300XX`.
  - Sin transformaciones `sed` (manifests ya con namespace correcto).
  - Escalado a 0 réplicas en `post.always` para conservar recursos.
  - Documentación en `docs/05-punto5-master.md`.
- Infraestructura como Código con Terraform:
  - Módulos para namespaces, config, postgres, neo4j, kafka, redis, openldap, microservicios.
  - Ambientes dev, stage y prod.
  - Backend remoto S3 + secretos AWS.

---

## [0.1.0] — 2026-05-12

### Added

- Pipeline Dev Environment (`Jenkinsfile.dev`):
  - Namespace `circleguard-dev`, tag `:dev`, NodePorts `310XX`.
  - 10 etapas: checkout, prepare, build JARs (paralelo), unit tests, integration tests, Docker build, deploy K8s, smoke tests, E2E (placeholder), performance (placeholder).
- 6 microservicios seleccionados e integrados: `file-service`, `gateway-service`, `dashboard-service`, `form-service`, `notification-service`, `promotion-service`.
- 5 pruebas unitarias (Mockito puro, sin Spring context).
- 5 pruebas de integración (Testcontainers + `@SpringBootTest`).
- 5 flujos E2E en `e2e/run_e2e.sh`.
- Pruebas de rendimiento con `locust/locustfile.py` (4 escenarios).
- Jenkins configurado como Multibranch Pipeline con imagen personalizada (`jenkins/Dockerfile`).
- Kubernetes en Docker Desktop con 3 namespaces (`circleguard`, `circleguard-dev`, `circleguard-stage`).
- Documentación inicial en `docs/`.

---

[Unreleased]: https://github.com/JuanCami009/circle-guard-public/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/JuanCami009/circle-guard-public/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/JuanCami009/circle-guard-public/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/JuanCami009/circle-guard-public/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/JuanCami009/circle-guard-public/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/JuanCami009/circle-guard-public/releases/tag/v0.1.0
