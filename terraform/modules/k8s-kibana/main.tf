# ---------------------------------------------------------------------------
# Kibana — visualiza logs de Elasticsearch indexados por Logstash/Filebeat.
# ---------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "kibana" {
  metadata {
    name      = "kibana"
    namespace = var.namespace
    labels    = { app = "kibana" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "kibana" }
    }

    template {
      metadata {
        labels = { app = "kibana" }
      }

      spec {
        container {
          name  = "kibana"
          image = var.image

          port {
            container_port = 5601
            name           = "http"
          }

          env {
            name  = "ELASTICSEARCH_HOSTS"
            value = var.elasticsearch_url
          }
          env {
            name  = "SERVER_NAME"
            value = "kibana"
          }
          env {
            name  = "XPACK_SECURITY_ENABLED"
            value = "false"
          }

          readiness_probe {
            http_get {
              path = "/api/status"
              port = 5601
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            failure_threshold     = 6
          }

          resources {
            requests = { memory = "256Mi", cpu = "200m" }
            limits   = { memory = "1Gi", cpu = "500m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kibana_svc" {
  metadata {
    name      = "kibana-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "kibana" }
    type     = "ClusterIP"
    port {
      port        = 5601
      target_port = 5601
    }
  }
}

resource "kubernetes_service_v1" "kibana_nodeport" {
  metadata {
    name      = "kibana-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = { app = "kibana" }
    type     = "NodePort"
    port {
      port        = 5601
      target_port = 5601
      node_port   = var.nodeport_ui
    }
  }
}
