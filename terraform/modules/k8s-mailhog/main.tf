# ---------------------------------------------------------------------------
# Raw Kubernetes resources — mirrors k8s/infra/08-mailhog.yml exactly.
# notification-service connects to mailhog-svc:1025 (SMTP).
# The MailHog web UI is exposed via NodePort at localhost:30025 for local dev.
# ---------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "mailhog" {
  wait_for_rollout = true
  metadata {
    name      = "mailhog"
    namespace = var.namespace
    labels = {
      app = "mailhog"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mailhog"
      }
    }

    template {
      metadata {
        labels = {
          app = "mailhog"
        }
      }

      spec {
        container {
          name  = "mailhog"
          image = var.image

          port {
            container_port = 1025
            name           = "smtp"
          }

          port {
            container_port = 8025
            name           = "http"
          }
        }
      }
    }
  }
}

# Internal ClusterIP service — notification-service sends mail to mailhog-svc:1025
resource "kubernetes_service_v1" "mailhog_svc" {
  metadata {
    name      = "mailhog-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "mailhog"
    }

    port {
      name        = "smtp"
      port        = 1025
      target_port = 1025
    }

    port {
      name        = "ui"
      port        = 8025
      target_port = 8025
    }

    type = "ClusterIP"
  }
}

# NodePort service — exposes the MailHog UI on the host at localhost:<nodeport_ui>
resource "kubernetes_service_v1" "mailhog_nodeport" {
  metadata {
    name      = "mailhog-nodeport"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "mailhog"
    }

    port {
      name        = "ui"
      port        = 8025
      target_port = 8025
      node_port   = var.nodeport_ui
    }

    type = "NodePort"
  }
}
