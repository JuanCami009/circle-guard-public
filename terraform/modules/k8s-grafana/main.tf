# ---------------------------------------------------------------------------
# Grafana — dashboards auto-provisionados via ConfigMaps.
# Datasources: Prometheus (métricas), Elasticsearch (logs), Zipkin (trazas).
# Dashboard técnico (JVM/HTTP por servicio) + dashboard de métricas de negocio.
# Admin user: admin / var.admin_password (default: circleguard)
# ---------------------------------------------------------------------------

# ── ConfigMap: datasources provisioning ─────────────────────────────────────
resource "kubernetes_config_map_v1" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = var.namespace
  }

  data = {
    "datasources.yaml" = <<-YAML
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          access: proxy
          url: ${var.prometheus_url}
          isDefault: true
          editable: false

        - name: Elasticsearch
          type: elasticsearch
          access: proxy
          url: ${var.elasticsearch_url}
          database: "circleguard-logs-*"
          jsonData:
            esVersion: "8.0.0"
            timeField: "@timestamp"
            logMessageField: message
            logLevelField: level
          editable: false

        - name: Zipkin
          type: zipkin
          access: proxy
          url: ${var.zipkin_url}
          editable: false
    YAML
  }
}

# ── ConfigMap: dashboard provisioning config ─────────────────────────────────
resource "kubernetes_config_map_v1" "grafana_dashboard_provider" {
  metadata {
    name      = "grafana-dashboard-provider"
    namespace = var.namespace
  }

  data = {
    "default.yaml" = <<-YAML
      apiVersion: 1
      providers:
        - name: CircleGuard
          orgId: 1
          type: file
          disableDeletion: false
          editable: true
          options:
            path: /var/lib/grafana/dashboards
    YAML
  }
}

# ── ConfigMap: dashboard JSON — técnico por servicio ────────────────────────
resource "kubernetes_config_map_v1" "grafana_dashboard_technical" {
  metadata {
    name      = "grafana-dashboard-technical"
    namespace = var.namespace
  }

  data = {
    "circleguard-services.json" = file("${path.module}/dashboards/circleguard-services.json")
  }
}

# ── ConfigMap: dashboard JSON — métricas de negocio ─────────────────────────
resource "kubernetes_config_map_v1" "grafana_dashboard_business" {
  metadata {
    name      = "grafana-dashboard-business"
    namespace = var.namespace
  }

  data = {
    "circleguard-business.json" = file("${path.module}/dashboards/circleguard-business.json")
  }
}

# ── Deployment ──────────────────────────────────────────────────────────────
resource "kubernetes_deployment_v1" "grafana" {
  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels    = { app = "grafana" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "grafana" }
    }

    template {
      metadata {
        labels = { app = "grafana" }
      }

      spec {
        container {
          name  = "grafana"
          image = var.image

          port {
            container_port = 3000
            name           = "http"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.admin_password
          }
          env {
            name  = "GF_PATHS_PROVISIONING"
            value = "/etc/grafana/provisioning"
          }
          env {
            name  = "GF_AUTH_ANONYMOUS_ENABLED"
            value = "false"
          }

          volume_mount {
            name       = "datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
            read_only  = true
          }

          volume_mount {
            name       = "dashboard-provider"
            mount_path = "/etc/grafana/provisioning/dashboards"
            read_only  = true
          }

          volume_mount {
            name       = "dashboard-technical"
            mount_path = "/var/lib/grafana/dashboards/technical"
            read_only  = true
          }

          volume_mount {
            name       = "dashboard-business"
            mount_path = "/var/lib/grafana/dashboards/business"
            read_only  = true
          }

          resources {
            requests = { memory = "256Mi", cpu = "100m" }
            limits   = { memory = "512Mi", cpu = "500m" }
          }
        }

        volume {
          name = "datasources"
          config_map {
            name = kubernetes_config_map_v1.grafana_datasources.metadata[0].name
          }
        }

        volume {
          name = "dashboard-provider"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard_provider.metadata[0].name
          }
        }

        volume {
          name = "dashboard-technical"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard_technical.metadata[0].name
          }
        }

        volume {
          name = "dashboard-business"
          config_map {
            name = kubernetes_config_map_v1.grafana_dashboard_business.metadata[0].name
          }
        }
      }
    }
  }
}

# ── ClusterIP Service ────────────────────────────────────────────────────────
resource "kubernetes_service_v1" "grafana_svc" {
  metadata {
    name      = "grafana-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "grafana" }
    type     = "ClusterIP"
    port {
      port        = 3000
      target_port = 3000
    }
  }
}

# ── NodePort Service (UI en el host) ─────────────────────────────────────────
resource "kubernetes_service_v1" "grafana_nodeport" {
  metadata {
    name      = "grafana-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = { app = "grafana" }
    type     = "NodePort"
    port {
      port        = 3000
      target_port = 3000
      node_port   = var.nodeport_ui
    }
  }
}
