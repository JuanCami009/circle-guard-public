# ---------------------------------------------------------------------------
# Filebeat — DaemonSet that tails /var/log/containers/*.log on every node
# and ships JSON log lines to Logstash:5044.
# RBAC: ServiceAccount + ClusterRole + ClusterRoleBinding so Filebeat can
# discover pods via the Kubernetes API (adds k8s metadata to every log line).
# ---------------------------------------------------------------------------

# ── RBAC ────────────────────────────────────────────────────────────────────
resource "kubernetes_service_account_v1" "filebeat" {
  metadata {
    name      = "filebeat"
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role_v1" "filebeat" {
  metadata {
    name = "filebeat-${var.namespace}"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "nodes"]
    verbs      = ["get", "watch", "list"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "filebeat" {
  metadata {
    name = "filebeat-${var.namespace}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.filebeat.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.filebeat.metadata[0].name
    namespace = var.namespace
  }
}

# ── ConfigMap: filebeat.yml ──────────────────────────────────────────────────
resource "kubernetes_config_map_v1" "filebeat_config" {
  metadata {
    name      = "filebeat-config"
    namespace = var.namespace
  }

  data = {
    "filebeat.yml" = <<-YAML
      filebeat.autodiscover:
        providers:
          - type: kubernetes
            node: $${NODE_NAME}
            hints.enabled: true
            hints.default_config:
              type: container
              paths:
                - /var/log/containers/*$${data.kubernetes.container.id}.log

      processors:
        - add_kubernetes_metadata:
            host: $${NODE_NAME}
            matchers:
              - logs_path:
                  logs_path: /var/log/containers/
        - decode_json_fields:
            fields: ["message"]
            target: ""
            overwrite_keys: true
            add_error_key: false

      output.logstash:
        hosts: ["${var.logstash_host}"]

      logging.level: warning
    YAML
  }
}

# ── DaemonSet ────────────────────────────────────────────────────────────────
resource "kubernetes_daemon_set_v1" "filebeat" {
  metadata {
    name      = "filebeat"
    namespace = var.namespace
    labels    = { app = "filebeat" }
  }

  spec {
    selector {
      match_labels = { app = "filebeat" }
    }

    template {
      metadata {
        labels = { app = "filebeat" }
      }

      spec {
        service_account_name             = kubernetes_service_account_v1.filebeat.metadata[0].name
        termination_grace_period_seconds = 30

        container {
          name  = "filebeat"
          image = var.image

          args = ["-c", "/etc/filebeat/filebeat.yml", "-e"]

          env {
            name = "NODE_NAME"
            value_from {
              field_ref { field_path = "spec.nodeName" }
            }
          }

          security_context {
            run_as_user = 0
          }

          volume_mount {
            name       = "config"
            mount_path = "/etc/filebeat"
            read_only  = true
          }

          volume_mount {
            name       = "varlogcontainers"
            mount_path = "/var/log/containers"
            read_only  = true
          }

          volume_mount {
            name       = "varlogpods"
            mount_path = "/var/log/pods"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }

          resources {
            requests = { memory = "128Mi", cpu = "100m" }
            limits   = { memory = "256Mi", cpu = "300m" }
          }
        }

        volume {
          name = "config"
          config_map {
            name         = kubernetes_config_map_v1.filebeat_config.metadata[0].name
            default_mode = "0644"
          }
        }

        volume {
          name = "varlogcontainers"
          host_path { path = "/var/log/containers" }
        }

        volume {
          name = "varlogpods"
          host_path { path = "/var/log/pods" }
        }

        volume {
          name = "varlibdockercontainers"
          host_path { path = "/var/lib/docker/containers" }
        }
      }
    }
  }
}
