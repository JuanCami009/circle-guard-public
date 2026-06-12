# ---------------------------------------------------------------------------
# Raw Kubernetes resources — mirrors k8s/infra/09-openldap.yml exactly.
# auth-service uses DualChainAuthenticationProvider which connects to
# ldap://openldap-svc:389 with base DN dc=circleguard,dc=edu.
# ---------------------------------------------------------------------------

resource "kubernetes_deployment_v1" "openldap" {
  wait_for_rollout = true
  metadata {
    name      = "openldap"
    namespace = var.namespace
    labels = {
      app = "openldap"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "openldap"
      }
    }

    template {
      metadata {
        labels = {
          app = "openldap"
        }
      }

      spec {
        container {
          name  = "openldap"
          image = var.image

          port {
            container_port = 389
          }

          env {
            name  = "LDAP_ORGANISATION"
            value = var.organisation
          }

          env {
            name  = "LDAP_DOMAIN"
            value = var.domain
          }

          env {
            name  = "LDAP_ADMIN_PASSWORD"
            value = var.admin_password
          }

          resources {
            requests = {
              memory = "128Mi"
              cpu    = "50m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "200m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "openldap_svc" {
  metadata {
    name      = "openldap-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "openldap"
    }

    port {
      port        = 389
      target_port = 389
    }

    type = "ClusterIP"
  }
}
