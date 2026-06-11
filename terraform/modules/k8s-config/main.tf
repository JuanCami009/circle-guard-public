data "aws_secretsmanager_secret_version" "secrets" {
  for_each  = nonsensitive(var.secret_arns)
  secret_id = each.value
}

locals {
  s = { for k, v in data.aws_secretsmanager_secret_version.secrets : k => jsondecode(v.secret_string) }
}

resource "kubernetes_config_map_v1" "circleguard_config" {
  metadata {
    name      = "circleguard-config"
    namespace = var.namespace
  }
  data = var.config_map_data
}

resource "kubernetes_secret_v1" "circleguard_secrets" {
  metadata {
    name      = "circleguard-secrets"
    namespace = var.namespace
  }
  data = {
    POSTGRES_USER                        = local.s["postgres"].username
    POSTGRES_PASSWORD                    = local.s["postgres"].password
    SPRING_DATASOURCE_USERNAME           = local.s["postgres"].username
    SPRING_DATASOURCE_PASSWORD           = local.s["postgres"].password
    SPRING_NEO4J_AUTHENTICATION_USERNAME = local.s["neo4j"].username
    SPRING_NEO4J_AUTHENTICATION_PASSWORD = local.s["neo4j"].password
    JWT_SECRET                           = local.s["jwt"].jwt_secret
    QR_SECRET                            = local.s["jwt"].qr_secret
    TWILIO_ACCOUNT_SID                   = local.s["twilio"].account_sid
    TWILIO_AUTH_TOKEN                    = local.s["twilio"].auth_token
    VAULT_SECRET                         = local.s["vault"].secret
    VAULT_SALT                           = local.s["vault"].salt
    VAULT_HASH_SALT                      = local.s["vault"].hash_salt
    LDAP_ADMIN_PASSWORD                  = local.s["ldap"].admin_password
    # ── Seguridad (Punto 8): SPRING_LDAP_PASSWORD en el Secret para que ──
    # auth-service lo reciba via envFrom y no necesite el valor inline.
    SPRING_LDAP_PASSWORD                 = local.s["ldap"].admin_password
  }
}
