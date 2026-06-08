# ---------------------------------------------------------------------------
# Alertmanager — receives alerts from Prometheus and routes them to email
# via MailHog SMTP (mailhog-svc:1025).  Alert emails are visible in MailHog
# UI at http://localhost:<mailhog-nodeport>.
# ---------------------------------------------------------------------------

resource "kubernetes_config_map_v1" "alertmanager_config" {
  metadata {
    name      = "alertmanager-config"
    namespace = var.namespace
  }

  data = {
    "alertmanager.yml" = <<-YAML
      global:
        smtp_smarthost: '${var.smtp_host}'
        smtp_from: '${var.smtp_from}'
        smtp_require_tls: false

      route:
        receiver: circleguard-email
        group_by: [alertname, application]
        group_wait:      30s
        group_interval:  5m
        repeat_interval: 1h
        routes:
          - match:
              severity: critical
            receiver: circleguard-email
            continue: false
          - match:
              severity: warning
            receiver: circleguard-email

      receivers:
        - name: circleguard-email
          email_configs:
            - to: '${var.alert_receiver_email}'
              send_resolved: true
              html: |
                <b>Alerta CircleGuard: {{ .GroupLabels.alertname }}</b><br/>
                {{ range .Alerts }}
                  <b>Descripción:</b> {{ .Annotations.description }}<br/>
                  <b>Severidad:</b> {{ .Labels.severity }}<br/>
                  <b>Estado:</b> {{ .Status }}<br/><br/>
                {{ end }}

      inhibit_rules:
        - source_match:
            severity: critical
          target_match:
            severity: warning
          equal: [alertname, application]
    YAML
  }
}

resource "kubernetes_deployment_v1" "alertmanager" {
  metadata {
    name      = "alertmanager"
    namespace = var.namespace
    labels    = { app = "alertmanager" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "alertmanager" }
    }

    template {
      metadata {
        labels = { app = "alertmanager" }
      }

      spec {
        container {
          name  = "alertmanager"
          image = var.image

          args = [
            "--config.file=/etc/alertmanager/alertmanager.yml",
            "--storage.path=/alertmanager",
          ]

          port {
            container_port = 9093
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/alertmanager"
            read_only  = true
          }

          volume_mount {
            name       = "data"
            mount_path = "/alertmanager"
          }

          resources {
            requests = { memory = "128Mi", cpu = "50m" }
            limits   = { memory = "256Mi", cpu = "200m" }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.alertmanager_config.metadata[0].name
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

resource "kubernetes_service_v1" "alertmanager_svc" {
  metadata {
    name      = "alertmanager-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "alertmanager" }
    type     = "ClusterIP"
    port {
      port        = 9093
      target_port = 9093
    }
  }
}

resource "kubernetes_service_v1" "alertmanager_nodeport" {
  metadata {
    name      = "alertmanager-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = { app = "alertmanager" }
    type     = "NodePort"
    port {
      port        = 9093
      target_port = 9093
      node_port   = var.nodeport_ui
    }
  }
}
