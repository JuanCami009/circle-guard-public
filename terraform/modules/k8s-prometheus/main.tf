# ---------------------------------------------------------------------------
# Prometheus — scrapes /actuator/prometheus on the 8 CircleGuard services.
# Alert rules are provisioned via ConfigMap. Alertmanager integration via
# remote_write / alerting block pointing to alertmanager-svc:9093.
# ---------------------------------------------------------------------------

# ── ConfigMap: prometheus.yml + alert rules ─────────────────────────────────
resource "kubernetes_config_map_v1" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = var.namespace
  }

  data = {
    "prometheus.yml" = <<-YAML
      global:
        scrape_interval:     15s
        evaluation_interval: 15s

      alerting:
        alertmanagers:
          - static_configs:
              - targets: ["alertmanager-svc:9093"]

      rule_files:
        - /etc/prometheus/alert.rules.yml

      scrape_configs:
        # ── CircleGuard microservices ─────────────────────────────────────
        - job_name: gateway-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["gateway-service-svc:8087"]
              labels: { application: gateway-service }

        - job_name: auth-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["auth-service-svc:8180"]
              labels: { application: auth-service }

        - job_name: identity-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["identity-service-svc:8083"]
              labels: { application: identity-service }

        - job_name: dashboard-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["dashboard-service-svc:8084"]
              labels: { application: dashboard-service }

        - job_name: file-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["file-service-svc:8085"]
              labels: { application: file-service }

        - job_name: form-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["form-service-svc:8086"]
              labels: { application: form-service }

        - job_name: notification-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["notification-service-svc:8082"]
              labels: { application: notification-service }

        - job_name: promotion-service
          metrics_path: /actuator/prometheus
          static_configs:
            - targets: ["promotion-service-svc:8088"]
              labels: { application: promotion-service }

        # ── Prometheus self-monitoring ────────────────────────────────────
        - job_name: prometheus
          static_configs:
            - targets: ["localhost:9090"]
    YAML

    "alert.rules.yml" = <<-YAML
      groups:
        - name: circleguard-service-alerts
          rules:
            # Servicio caído: up == 0 durante 1 minuto
            - alert: ServiceDown
              expr: up == 0
              for: 1m
              labels:
                severity: critical
              annotations:
                summary: "Servicio {{ $labels.job }} no disponible"
                description: "El servicio {{ $labels.job }} lleva más de 1 minuto caído (instancia {{ $labels.instance }})."

            # Alta tasa de errores 5xx (>5% de peticiones en ventana 5m)
            - alert: HighErrorRate
              expr: |
                rate(http_server_requests_seconds_count{outcome="SERVER_ERROR"}[5m])
                /
                rate(http_server_requests_seconds_count[5m]) > 0.05
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Alta tasa de errores en {{ $labels.application }}"
                description: "Servicio {{ $labels.application }} tiene >5% de respuestas 5xx en los últimos 5 minutos."

            # Latencia p99 >1 segundo
            - alert: HighLatencyP99
              expr: |
                histogram_quantile(0.99,
                  rate(http_server_requests_seconds_bucket[5m])
                ) > 1.0
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Latencia p99 elevada en {{ $labels.application }}"
                description: "Percentil 99 de latencia supera 1s en {{ $labels.application }} (URI {{ $labels.uri }})."

            # Uso de heap JVM >90%
            - alert: HighJvmHeapUsage
              expr: |
                jvm_memory_used_bytes{area="heap"}
                /
                jvm_memory_max_bytes{area="heap"} > 0.90
              for: 5m
              labels:
                severity: warning
              annotations:
                summary: "Heap JVM alto en {{ $labels.application }}"
                description: "El heap JVM de {{ $labels.application }} supera el 90% de capacidad."

        - name: circleguard-business-alerts
          rules:
            # Alerta de negocio: sin cambios de estado de salud en la última hora
            - alert: NoHealthStatusUpdates
              expr: |
                increase(circleguard_health_status_updates_total[1h]) == 0
              for: 0m
              labels:
                severity: info
              annotations:
                summary: "Sin actualizaciones de estado de salud en 1 hora"
                description: "promotion-service no ha registrado cambios de estado en la última hora. Puede indicar que el pipeline de encuestas no está funcionando."
    YAML
  }
}

# ── Deployment ──────────────────────────────────────────────────────────────
resource "kubernetes_deployment_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
    labels    = { app = "prometheus" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "prometheus" }
    }

    template {
      metadata {
        labels = { app = "prometheus" }
      }

      spec {
        container {
          name  = "prometheus"
          image = var.image

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles",
          ]

          port {
            container_port = 9090
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/prometheus"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/prometheus"
          }

          resources {
            requests = { memory = "256Mi", cpu = "100m" }
            limits   = { memory = "512Mi", cpu = "500m" }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

# ── ClusterIP Service (Grafana + Alertmanager lo usan internamente) ──────────
resource "kubernetes_service_v1" "prometheus_svc" {
  metadata {
    name      = "prometheus-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "prometheus" }
    type     = "ClusterIP"
    port {
      port        = 9090
      target_port = 9090
    }
  }
}

# ── NodePort Service (UI en el host) ─────────────────────────────────────────
resource "kubernetes_service_v1" "prometheus_nodeport" {
  metadata {
    name      = "prometheus-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = { app = "prometheus" }
    type     = "NodePort"
    port {
      port        = 9090
      target_port = 9090
      node_port   = var.nodeport_ui
    }
  }
}
