# ---------------------------------------------------------------------------
# RBAC (Punto 8 — Seguridad)
#
# Crea recursos de control de acceso para el namespace de CircleGuard:
#
#   1. ServiceAccount dedicada por microservicio (automount disabled).
#      Las apps Spring no consumen la API de Kubernetes, por lo que montar
#      el token de la SA default es superficie de ataque innecesaria.
#
#   2. Role "circleguard-developer" (read-only) + RoleBinding.
#      Permite a operadores/SREs inspeccionar pods/logs sin permisos de
#      escritura.
#
#   3. Role "circleguard-ci-deployer" (deploy) + RoleBinding.
#      Otorga a la SA "ci-deployer" los permisos mínimos para que el
#      pipeline de Jenkins aplique manifests sin necesitar cluster-admin.
#
# Convención (igual que k8s-filebeat): ClusterRole/ClusterRoleBinding usan
# sufijo "-${var.namespace}" para no colisionar entre envs en el mismo clúster.
# ---------------------------------------------------------------------------

# ── 1. ServiceAccounts por microservicio ─────────────────────────────────────
resource "kubernetes_service_account_v1" "microservices" {
  for_each = toset(var.service_names)

  metadata {
    name      = "${each.key}-sa"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "circleguard/security"         = "punto8"
    }
  }

  # Las apps Spring no leen la API de Kubernetes → token innecesario
  automount_service_account_token = false
}

# ── 2. SA especiales para operaciones (developer y ci-deployer) ──────────────
resource "kubernetes_service_account_v1" "developer" {
  metadata {
    name      = "developer"
    namespace = var.namespace
  }
}

resource "kubernetes_service_account_v1" "ci_deployer" {
  metadata {
    name      = "ci-deployer"
    namespace = var.namespace
  }
}

# ── 3. Role: developer (read-only sobre recursos de app) ─────────────────────
resource "kubernetes_role_v1" "developer" {
  metadata {
    name      = "circleguard-developer"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "services", "configmaps", "endpoints"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "developer" {
  metadata {
    name      = "circleguard-developer"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.developer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.developer.metadata[0].name
    namespace = var.namespace
  }
}

# ── 4. Role: ci-deployer (gestión de deployments para pipeline Jenkins) ───────
resource "kubernetes_role_v1" "ci_deployer" {
  metadata {
    name      = "circleguard-ci-deployer"
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = ["services", "configmaps", "pods", "pods/log"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

resource "kubernetes_role_binding_v1" "ci_deployer" {
  metadata {
    name      = "circleguard-ci-deployer"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.ci_deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.ci_deployer.metadata[0].name
    namespace = var.namespace
  }
}
