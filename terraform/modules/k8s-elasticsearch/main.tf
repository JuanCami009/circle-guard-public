# ---------------------------------------------------------------------------
# Elasticsearch 8.x single-node — security disabled for local dev.
# Logstash writes to it; Kibana reads from it; Grafana datasource points here.
# ---------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "elasticsearch" {
  metadata {
    name      = "elasticsearch"
    namespace = var.namespace
    labels    = { app = "elasticsearch" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "elasticsearch" }
    }

    template {
      metadata {
        labels = { app = "elasticsearch" }
      }

      spec {
        # ES requires vm.max_map_count=262144; init container sets it
        init_container {
          name  = "sysctl"
          image = "busybox:1.36"
          command = ["sysctl", "-w", "vm.max_map_count=262144"]
          security_context {
            privileged = true
          }
        }

        container {
          name  = "elasticsearch"
          image = var.image

          port {
            container_port = 9200
            name           = "http"
          }

          env {
            name  = "discovery.type"
            value = "single-node"
          }
          env {
            name  = "xpack.security.enabled"
            value = "false"
          }
          env {
            name  = "ES_JAVA_OPTS"
            value = "-Xms256m -Xmx512m"
          }

          readiness_probe {
            http_get {
              path = "/_cluster/health?wait_for_status=yellow&timeout=5s"
              port = 9200
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            failure_threshold     = 6
          }

          resources {
            requests = { memory = "512Mi", cpu = "200m" }
            limits   = { memory = "1Gi", cpu = "1000m" }
          }

          volume_mount {
            name       = "data"
            mount_path = "/usr/share/elasticsearch/data"
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

resource "kubernetes_service_v1" "elasticsearch_svc" {
  metadata {
    name      = "elasticsearch-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "elasticsearch" }
    type     = "ClusterIP"
    port {
      port        = 9200
      target_port = 9200
    }
  }
}
