# ---------------------------------------------------------------------------
# Ingress-nginx + TLS (Punto 8 — Seguridad)
#
# Instala el controlador ingress-nginx vía Helm con NodePorts configurados,
# genera un certificado TLS self-signed (hashicorp/tls) y crea el Ingress
# HTTPS que expone el gateway-service en https://circleguard.local.
#
# Uso (local/dev):
#   echo "127.0.0.1 circleguard.local" | sudo tee -a /etc/hosts
#   curl -k -H 'Host: circleguard.local' https://localhost:<nodeport_https>/
# ---------------------------------------------------------------------------

# ── Controlador ingress-nginx (Helm) ─────────────────────────────────────────
resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  wait             = true
  timeout          = 120

  set {
    name  = "controller.service.type"
    value = "NodePort"
  }
  set {
    name  = "controller.service.nodePorts.http"
    value = tostring(var.nodeport_http)
  }
  set {
    name  = "controller.service.nodePorts.https"
    value = tostring(var.nodeport_https)
  }
  # Permite que el controlador admita Ingress de cualquier namespace
  set {
    name  = "controller.watchIngressWithoutClass"
    value = "true"
  }
}

# ── Certificado TLS self-signed ───────────────────────────────────────────────
resource "tls_private_key" "circleguard" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "circleguard" {
  private_key_pem = tls_private_key.circleguard.private_key_pem

  subject {
    common_name  = var.ingress_host
    organization = "CircleGuard"
  }

  dns_names             = [var.ingress_host, "*.${var.ingress_host}"]
  validity_period_hours = 8760 # 365 días
  early_renewal_hours   = 168  # 7 días

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# ── Secret TLS (kubernetes.io/tls) ───────────────────────────────────────────
resource "kubernetes_secret_v1" "tls" {
  metadata {
    name      = var.tls_secret_name
    namespace = var.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.circleguard.cert_pem
    "tls.key" = tls_private_key.circleguard.private_key_pem
  }
}

# ── Ingress HTTPS → gateway-service ──────────────────────────────────────────
resource "kubernetes_ingress_v1" "gateway" {
  metadata {
    name      = "circleguard-ingress"
    namespace = var.namespace
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect"   = "true"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
      "nginx.ingress.kubernetes.io/use-regex"      = "true"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts       = [var.ingress_host]
      secret_name = kubernetes_secret_v1.tls.metadata[0].name
    }

    rule {
      host = var.ingress_host

      http {
        path {
          path      = "/()(.*)"
          path_type = "ImplementationSpecific"

          backend {
            service {
              name = var.gateway_service_name
              port {
                number = var.gateway_port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.ingress_nginx]
}
