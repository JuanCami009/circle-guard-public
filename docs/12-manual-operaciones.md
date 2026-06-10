# Manual de Operaciones - CircleGuard

## Accesos y URLs por entorno

| Herramienta | Dev (31xxx) | Stage (32xxx) | Prod (30xxx) |
|---|---|---|---|
| Jenkins | `http://localhost:8080` | - | - |
| Grafana | `http://localhost:31091` | `http://localhost:32091` | `http://localhost:30091` |
| Kibana | `http://localhost:31092` | `http://localhost:32092` | `http://localhost:30092` |
| Zipkin | `http://localhost:31093` | `http://localhost:32093` | `http://localhost:30093` |
| Alertmanager | `http://localhost:31094` | `http://localhost:32094` | `http://localhost:30094` |
| Prometheus | `http://localhost:31090` | `http://localhost:32090` | `http://localhost:30090` |
| MailHog (SMTP UI) | `http://localhost:31025` | - | `http://localhost:30025` |

Credenciales Grafana: `admin` / `circleguard` (configurable en `terraform/modules/k8s-grafana/main.tf:GF_SECURITY_ADMIN_PASSWORD`).

Namespace por entorno: `circleguard-dev` / `circleguard-stage` / `circleguard-prod`.

---

## 1. Despliegue y arranque

### Con Terraform (recomendado)

```bash
# Prod
cd terraform/envs/prod
terraform init
terraform apply -auto-approve

# Dev
cd terraform/envs/dev
terraform init
terraform apply -auto-approve
```

### Con kubectl (manifests directos)

```bash
# Infraestructura (orden importa)
kubectl apply -f k8s/infra/ -n circleguard-dev

# Servicios
kubectl apply -f k8s/services/ -n circleguard-dev
```

---

## 2. Verificación de salud

```bash
# Estado de todos los pods
kubectl get pods -n circleguard-prod

# Health check HTTP de los 8 microservicios (prod NodePorts)
for port in 30082 30083 30084 30085 30086 30087 30088 30180; do
  echo -n "Puerto $port: "
  curl -s http://host.docker.internal:$port/actuator/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))"
done

# Estado en Prometheus (targets activos)
curl -s 'http://localhost:30090/api/v1/query?query=up' | python3 -c \
  "import sys,json; d=json.load(sys.stdin); [print(r['metric'].get('job','?'), r['value'][1]) for r in d['data']['result']]"
```

---

## 3. Logs

### Ver logs de un servicio

```bash
# Últimas 100 líneas, prod
kubectl logs -n circleguard-prod -l app=circleguard-auth-service --tail=100

# Seguir en tiempo real
kubectl logs -n circleguard-prod -l app=circleguard-gateway-service --tail=50 -f
```

### Buscar por traceId (Kibana)

1. Abrir Kibana en `http://localhost:30092`.
2. `Discover` → index pattern `circleguard-*`.
3. Filtro: `traceId: <id-del-trace>`.
4. Campo `spanId` permite ver el árbol de llamadas; campo `service` filtra por microservicio.

Todos los logs están en JSON estructurado con `traceId` y `spanId` inyectados por Zipkin/Micrometer Tracing (configurado en `logback-spring.xml` de cada servicio).

---

## 4. Rollback de un servicio

```bash
# Listar historial de revisiones
kubectl rollout history deployment/circleguard-auth-service -n circleguard-prod

# Rollback a la revisión anterior (más común)
kubectl rollout undo deployment/circleguard-auth-service -n circleguard-prod

# Rollback a una revisión específica
kubectl rollout undo deployment/circleguard-auth-service -n circleguard-prod --to-revision=2

# Verificar que el rollback terminó
kubectl rollout status deployment/circleguard-auth-service -n circleguard-prod
```

Para rollback completo del entorno via Terraform:

```bash
cd terraform/envs/prod
git checkout <tag-anterior>   # p.ej. v1.2.0
terraform apply -auto-approve
```

---

## 5. Escalado manual

```bash
# Escalar un servicio
kubectl scale deployment circleguard-gateway-service --replicas=3 -n circleguard-prod

# Verificar distribución de pods
kubectl get pods -n circleguard-prod -l app=circleguard-gateway-service
```

`promotion-service` es el servicio más intensivo en recursos (1Gi RAM request, 2Gi limit). Escalar requiere suficiente capacidad en el nodo.

---

## 6. Alertas

### Reglas activas (Prometheus)

| Alerta | Condición | Severidad |
|---|---|---|
| `ServiceDown` | Pod ausente > 1 minuto | Critical |
| `HighErrorRate` | Tasa 5xx > 5% durante 5 min | Critical |
| `HighLatencyP99` | P99 > 2 segundos durante 10 min | Warning |
| `HighJvmHeapUsage` | Heap usado > 85% durante 5 min | Warning |
| `NoHealthStatusUpdates` | Sin actualizaciones de estado 15 min | Warning |

Definidas en `terraform/modules/k8s-prometheus/main.tf`. Critical inhibe Warning del mismo servicio.

### Destino de alertas

- **Dev/Stage:** MailHog UI (`http://localhost:31025`) - sin envío SMTP real.
- **Prod:** SMTP configurable vía `var.smtp_host` / `var.smtp_from` / `var.alert_receiver_email` en `terraform/modules/k8s-alertmanager/`.

---

## 7. Troubleshooting común

| Síntoma | Causa probable | Diagnóstico |
|---|---|---|
| Pod en `CrashLoopBackOff` | Init container falla (BD no lista) | `kubectl describe pod <pod> -n <ns>` - ver eventos |
| `503 Service Unavailable` desde gateway | Servicio destino caído | `up{job="circleguard-<svc>"}` en Prometheus |
| Logs no aparecen en Kibana | Filebeat o Logstash caído | `kubectl get pods -n <ns> \| grep -E "filebeat\|logstash"` |
| QR token rechazado con 401 | `QR_SECRET` distinto entre auth y gateway | `kubectl get configmap circleguard-config -n <ns> -o yaml \| grep QR_SECRET` |
| Kafka consumer lag creciente | promotion o notification saturados | Ver métricas JVM heap en Grafana → escalar réplicas |
| Trazas no aparecen en Zipkin | `MANAGEMENT_ZIPKIN_TRACING_ENDPOINT` incorrecto | `kubectl get configmap circleguard-config -n <ns> -o yaml \| grep ZIPKIN` |

---

## 8. Backup y restauración

### PostgreSQL

```bash
# Backup
kubectl exec -n circleguard-prod deploy/postgres -- \
  pg_dump -U circleguard circleguard_db > backup-$(date +%Y%m%d).sql

# Restaurar
kubectl exec -i -n circleguard-prod deploy/postgres -- \
  psql -U circleguard circleguard_db < backup-20260609.sql
```

### Neo4j

```bash
# Backup (modo offline - detener neo4j primero)
kubectl scale deployment neo4j --replicas=0 -n circleguard-prod
kubectl exec -n circleguard-prod deploy/neo4j -- neo4j-admin database dump neo4j --to-stdout > neo4j-backup-$(date +%Y%m%d).dump
kubectl scale deployment neo4j --replicas=1 -n circleguard-prod
```

---

## 9. Teardown

```bash
# Destruir entorno completo (irreversible)
cd terraform/envs/prod
terraform destroy -auto-approve

# O solo un servicio (sin destruir infra)
kubectl delete deployment circleguard-auth-service -n circleguard-prod
```
