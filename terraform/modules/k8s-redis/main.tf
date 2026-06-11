# ---------------------------------------------------------------------------
# bitnami/redis Helm chart — standalone, no auth.
# fullnameOverride = "redis-svc" matches the existing ConfigMap entry
# SPRING_DATA_REDIS_HOST=redis-svc used by all Spring Boot microservices.
# ---------------------------------------------------------------------------

resource "helm_release" "redis" {
  name       = "redis"
  chart      = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  version    = var.chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 600

  set {
    name  = "architecture"
    value = var.architecture
  }

  # No password — matches existing k8s/infra/07-redis.yml (plain redis:7.2, no auth)
  set {
    name  = "auth.enabled"
    value = "false"
  }

  # Service name resolves to redis-svc inside the cluster
  set {
    name  = "fullnameOverride"
    value = "redis-svc"
  }

  set {
    name  = "master.service.ports.redis"
    value = "6379"
  }

  # Disable PVC — kind's default storage class is slow to provision and blocks pod start
  set {
    name  = "master.persistence.enabled"
    value = "false"
  }
}
