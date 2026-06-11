resource "kubernetes_deployment_v1" "neo4j" {
  metadata {
    name      = "neo4j"
    namespace = var.namespace
    labels = {
      app = "neo4j"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "neo4j"
      }
    }

    template {
      metadata {
        labels = {
          app = "neo4j"
        }
      }

      spec {
        # Prevent Neo4j from inheriting k8s service env vars (avoids port conflicts)
        enable_service_links = false

        container {
          name  = "neo4j"
          image = var.image

          port {
            container_port = 7474
            name           = "http"
          }

          port {
            container_port = 7687
            name           = "bolt"
          }

          # NEO4J_AUTH: use secret if provided, otherwise default plaintext
          dynamic "env" {
            for_each = var.auth_secret_name != "" ? [1] : []
            content {
              name = "NEO4J_AUTH"
              value_from {
                secret_key_ref {
                  name = var.auth_secret_name
                  key  = "NEO4J_AUTH"
                }
              }
            }
          }

          dynamic "env" {
            for_each = var.auth_secret_name == "" ? [1] : []
            content {
              name  = "NEO4J_AUTH"
              value = "neo4j/password"
            }
          }

          env {
            name  = "NEO4J_dbms_connector_bolt_listen__address"
            value = ":7687"
          }

          env {
            name  = "NEO4J_dbms_connector_bolt_advertised__address"
            value = ":7687"
          }

          env {
            name  = "NEO4J_server_memory_heap_initial__size"
            value = "128m"
          }

          env {
            name  = "NEO4J_server_memory_heap_max__size"
            value = "256m"
          }

          env {
            name  = "NEO4J_server_memory_pagecache__size"
            value = "128m"
          }

          # readinessProbe: httpGet on 7474 (matches k8s/infra/04-neo4j.yml ground truth)
          readiness_probe {
            http_get {
              path = "/"
              port = 7474
            }
            initial_delay_seconds = 60
            period_seconds        = 15
            failure_threshold     = 20
          }

          resources {
            requests = var.resources.requests
            limits   = var.resources.limits
          }

          volume_mount {
            name       = "neo4jdata"
            mount_path = "/data"
          }
        }

        volume {
          name = "neo4jdata"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "neo4j_svc" {
  metadata {
    name      = "neo4j-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "neo4j"
    }

    port {
      name        = "http"
      port        = 7474
      target_port = 7474
    }

    port {
      name        = "bolt"
      port        = 7687
      target_port = 7687
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "neo4j_nodeport" {
  metadata {
    name      = "neo4j-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "neo4j"
    }

    port {
      name        = "http"
      port        = 7474
      target_port = 7474
      node_port   = var.nodeport_browser
    }

    type = "NodePort"
  }
}
