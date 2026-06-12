locals {
  init_sql = join("\n", [
    for db in var.databases :
    "SELECT 'CREATE DATABASE ${db}' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\\gexec"
  ])
}

resource "kubernetes_config_map_v1" "postgres_init_sql" {
  metadata {
    name      = "postgres-init-sql"
    namespace = var.namespace
  }

  data = {
    "init-db.sql" = local.init_sql
  }
}

resource "kubernetes_deployment_v1" "postgres" {
  wait_for_rollout = false
  metadata {
    name      = "postgres"
    namespace = var.namespace
    labels = {
      app = "postgres"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = var.image

          port {
            container_port = 5432
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "POSTGRES_USER"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name  = "POSTGRES_DB"
            value = "circleguard"
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "admin"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }

          resources {
            requests = var.resources.requests
            limits   = var.resources.limits
          }

          volume_mount {
            name       = "init-sql"
            mount_path = "/docker-entrypoint-initdb.d"
            read_only  = true
          }

          volume_mount {
            name       = "pgdata"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "init-sql"
          config_map {
            name = kubernetes_config_map_v1.postgres_init_sql.metadata[0].name
          }
        }

        volume {
          name = "pgdata"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "postgres_svc" {
  metadata {
    name      = "postgres-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}
