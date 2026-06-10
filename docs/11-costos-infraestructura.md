# Costos de Infraestructura - CircleGuard

## Resumen

Este documento estima el costo de la infraestructura CircleGuard en un entorno de nube pública real (AWS EKS, us-east-1). El entorno actual de desarrollo usa Docker Desktop con LocalStack - costo operativo en desarrollo: **$0**.

---

## Recursos del clúster (producción)

Los recursos están definidos en `terraform/envs/prod/main.tf` y los módulos `terraform/modules/k8s-*/`.

### Microservicios (8 servicios)

| Servicio | Réplicas | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|---|
| auth-service | 1 | 100m | 500m | 256Mi | 512Mi |
| identity-service | 1 | 100m | 500m | 256Mi | 512Mi |
| file-service | 1 | 100m | 500m | 256Mi | 512Mi |
| gateway-service | 1 | 100m | 500m | 256Mi | 512Mi |
| dashboard-service | 1 | 100m | 500m | 256Mi | 512Mi |
| form-service | 1 | 100m | 500m | 256Mi | 512Mi |
| notification-service | 1 | 100m | 500m | 256Mi | 512Mi |
| promotion-service | 1 | 500m | 2000m | 1Gi | 2Gi |

> `promotion-service` es más intensivo: mantiene el grafo Neo4j de contacto en memoria y procesa eventos Kafka en tiempo real.

**Subtotal microservicios**: ~1.3 CPU cores (requests), ~3.75Gi RAM (requests).

### Observabilidad (8 componentes)

| Componente | Réplicas | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|---|
| Elasticsearch | 1 | 200m | 1000m | 1Gi | 2Gi |
| Logstash | 1 | 100m | 500m | 256Mi | 512Mi |
| Kibana | 1 | 100m | 500m | 256Mi | 512Mi |
| Filebeat (DaemonSet) | 1/nodo | 100m | 500m | 256Mi | 512Mi |
| Prometheus | 1 | 100m | 500m | 256Mi | 512Mi |
| Grafana | 1 | 100m | 500m | 128Mi | 256Mi |
| Zipkin | 1 | 100m | 500m | 256Mi | 512Mi |
| Alertmanager | 1 | 100m | 200m | 128Mi | 256Mi |

**Subtotal observabilidad**: ~1.0 CPU core (requests), ~2.6Gi RAM (requests).

### Infraestructura de datos (6 componentes)

| Componente | Réplicas | CPU request | CPU limit | Mem request | Mem limit |
|---|---|---|---|---|---|
| PostgreSQL | 1 | 250m | 500m | 256Mi | 512Mi |
| Neo4j | 1 | 500m | 1000m | 512Mi | 1Gi |
| Kafka | 1 | 250m | 500m | 512Mi | 1Gi |
| Zookeeper | 1 | 100m | 200m | 256Mi | 512Mi |
| Redis | 1 | 100m | 200m | 128Mi | 256Mi |
| OpenLDAP | 1 | 100m | 200m | 128Mi | 256Mi |

**Subtotal datos**: ~1.3 CPU cores (requests), ~1.8Gi RAM (requests).

### Totales del clúster

| Métrica | Requests | Limits |
|---|---|---|
| CPU total | ~3.6 vCPU | ~10.1 vCPU |
| RAM total | ~8.15Gi | ~16.8Gi |

---

## Estimación de costos en AWS (us-east-1)

Referencia académica - precios On-Demand aproximados a junio 2026.

### Opción A - Nodo único (desarrollo/demo)

| Recurso | Tipo | Cantidad | Precio/mes |
|---|---|---|---|
| EC2 t3.2xlarge (8 vCPU, 32Gi) | Compute | 1 nodo | ~$240 |
| EKS Control Plane | Managed | 1 cluster | $72 |
| EBS gp3 - PostgreSQL (20 GB) | Storage | 1 vol. | ~$1.60 |
| EBS gp3 - Neo4j (20 GB) | Storage | 1 vol. | ~$1.60 |
| EBS gp3 - Elasticsearch (30 GB) | Storage | 1 vol. | ~$2.40 |
| S3 circleguard-uploads (10 GB) | Storage | 1 bucket | ~$0.23 |
| Secrets Manager (10 secretos) | Managed | 10 secrets | ~$4 |
| Bandwidth saliente (50 GB/mes) | Network | - | ~$4.50 |
| **Total (nodo único)** | | | **~$326/mes** |

### Opción B - Multi-nodo (producción real, alta disponibilidad)

| Recurso | Tipo | Cantidad | Precio/mes |
|---|---|---|---|
| EC2 t3.xlarge (4 vCPU, 16Gi) - microservicios | Compute | 2 nodos | ~$240 |
| EC2 t3.large (2 vCPU, 8Gi) - observabilidad | Compute | 1 nodo | ~$60 |
| EC2 t3.xlarge - datos (Neo4j, Kafka, ES) | Compute | 1 nodo | ~$120 |
| EKS Control Plane | Managed | 1 cluster | $72 |
| EBS gp3 - almacenamiento persistente (100 GB total) | Storage | - | ~$8 |
| S3 + Secrets Manager | Managed | - | ~$5 |
| Bandwidth + misc | - | - | ~$10 |
| **Total (multi-nodo prod)** | | | **~$515/mes** |

### Opción C - Entorno actual (Docker Desktop + LocalStack)

| Recurso | Costo |
|---|---|
| Docker Desktop | $0 (uso personal) |
| LocalStack (S3, Secrets Manager simulados) | $0 |
| Jenkins (contenedor local) | $0 |
| **Total desarrollo local** | **$0/mes** |

---

## Optimizaciones de costo

| Estrategia | Ahorro estimado |
|---|---|
| EC2 Spot Instances para nodos de stage | ~60-70% en compute de stage |
| Reserved Instances (1 año) para prod | ~30-40% en compute de prod |
| RDS PostgreSQL managed (elimina gestión PV) | Simplificación operativa; costo similar |
| Compartir clúster entre dev y stage (namespaces) | Eliminar 1-2 nodos |
| Apagar entorno stage fuera de horario laboral | ~65% en compute de stage |

---

## Comparación entre entornos

| Entorno | Nodes | Namespaces | NodePort base | Costo estimado/mes |
|---|---|---|---|---|
| dev (local) | Docker Desktop | circleguard-dev | 31000 | $0 |
| stage (local) | Docker Desktop | circleguard-stage | 32000 | $0 |
| prod (AWS EKS ref.) | 1-4 EC2 | circleguard-prod | 30000 | $326–$515 |
