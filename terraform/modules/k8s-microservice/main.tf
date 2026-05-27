resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      app = var.name
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        # ── initContainers: wait for dependencies before starting ──────────
        dynamic "init_container" {
          for_each = var.init_wait_for
          content {
            name              = init_container.value.name
            image             = "busybox:1.36"
            image_pull_policy = "IfNotPresent"
            command = [
              "sh", "-c",
              "until nc -z ${init_container.value.host} ${init_container.value.port}; do echo 'Waiting for ${init_container.value.name}...'; sleep 5; done; echo '${init_container.value.name} is ready.'"
            ]
          }
        }

        # ── main container ─────────────────────────────────────────────────
        container {
          name              = var.name
          image             = "${var.image}:${var.image_tag}"
          image_pull_policy = var.image_pull_policy

          port {
            container_port = var.container_port
          }

          readiness_probe {
            tcp_socket {
              # kubernetes provider v2 requires port as a string here
              port = tostring(var.container_port)
            }
            initial_delay_seconds = 20
            period_seconds        = 5
            failure_threshold     = 12
          }

          # envFrom: ConfigMap (optional)
          dynamic "env_from" {
            for_each = var.config_map_ref != null ? [var.config_map_ref] : []
            content {
              config_map_ref {
                name = env_from.value
              }
            }
          }

          # envFrom: Secret (optional)
          dynamic "env_from" {
            for_each = var.secret_ref != null ? [var.secret_ref] : []
            content {
              secret_ref {
                name = env_from.value
              }
            }
          }

          # extra env vars applied after envFrom (e.g. SERVER_PORT, SPRING_DATASOURCE_URL)
          dynamic "env" {
            for_each = var.extra_env
            content {
              name  = env.key
              value = env.value
            }
          }

          resources {
            requests = var.resources.requests
            limits   = var.resources.limits
          }

          # additional volume mounts (e.g. file-service uploads dir)
          dynamic "volume_mount" {
            for_each = var.volume_mounts
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.mount_path
              read_only  = volume_mount.value.read_only
            }
          }
        }

        # ── volumes ────────────────────────────────────────────────────────
        dynamic "volume" {
          for_each = var.volumes
          content {
            name = volume.value.name

            dynamic "empty_dir" {
              for_each = volume.value.type == "emptyDir" ? [1] : []
              content {}
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = "${var.name}-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = var.name
    }

    type = var.service_type

    port {
      port        = var.container_port
      target_port = var.container_port
      # node_port is only valid for NodePort services; null is accepted by the
      # provider to omit the field when service_type == "ClusterIP"
      node_port = var.service_type == "NodePort" ? var.nodeport : null
    }
  }
}
