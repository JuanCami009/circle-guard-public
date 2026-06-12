# ---------------------------------------------------------------------------
# Zipkin — receives distributed trace spans from the 8 Spring Boot services
# via micrometer-tracing-bridge-brave + zipkin-reporter-brave.
# Services send spans to http://zipkin-svc:9411/api/v2/spans (env var
# MANAGEMENT_ZIPKIN_TRACING_ENDPOINT in the shared ConfigMap).
# ---------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "zipkin" {
  wait_for_rollout = false
  metadata {
    name      = "zipkin"
    namespace = var.namespace
    labels    = { app = "zipkin" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "zipkin" }
    }

    template {
      metadata {
        labels = { app = "zipkin" }
      }

      spec {
        container {
          name  = "zipkin"
          image = var.image

          port {
            container_port = 9411
            name           = "http"
          }

          env {
            name  = "STORAGE_TYPE"
            value = "mem"
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 9411
            }
            initial_delay_seconds = 10
            period_seconds        = 5
            failure_threshold     = 6
          }

          resources {
            requests = { memory = "256Mi", cpu = "100m" }
            limits   = { memory = "512Mi", cpu = "500m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "zipkin_svc" {
  metadata {
    name      = "zipkin-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "zipkin" }
    type     = "ClusterIP"
    port {
      port        = 9411
      target_port = 9411
    }
  }
}

resource "kubernetes_service_v1" "zipkin_nodeport" {
  metadata {
    name      = "zipkin-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = { app = "zipkin" }
    type     = "NodePort"
    port {
      port        = 9411
      target_port = 9411
      node_port   = var.nodeport_ui
    }
  }
}
