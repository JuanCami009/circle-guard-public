data "aws_secretsmanager_secret_version" "jwt" {
  secret_id = var.secret_arns["jwt"]
}

data "aws_secretsmanager_secret_version" "postgres" {
  secret_id = var.secret_arns["postgres"]
}

data "aws_secretsmanager_secret_version" "neo4j" {
  secret_id = var.secret_arns["neo4j"]
}

data "aws_secretsmanager_secret_version" "twilio" {
  secret_id = var.secret_arns["twilio"]
}

data "aws_secretsmanager_secret_version" "vault" {
  secret_id = var.secret_arns["vault"]
}

data "aws_secretsmanager_secret_version" "ldap" {
  secret_id = var.secret_arns["ldap"]
}

locals {
  jwt      = jsondecode(data.aws_secretsmanager_secret_version.jwt.secret_string)
  postgres = jsondecode(data.aws_secretsmanager_secret_version.postgres.secret_string)
  neo4j    = jsondecode(data.aws_secretsmanager_secret_version.neo4j.secret_string)
  twilio   = jsondecode(data.aws_secretsmanager_secret_version.twilio.secret_string)
  vault    = jsondecode(data.aws_secretsmanager_secret_version.vault.secret_string)
  ldap     = jsondecode(data.aws_secretsmanager_secret_version.ldap.secret_string)
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
    POSTGRES_USER                        = local.postgres.username
    POSTGRES_PASSWORD                    = local.postgres.password
    SPRING_DATASOURCE_USERNAME           = local.postgres.username
    SPRING_DATASOURCE_PASSWORD           = local.postgres.password
    SPRING_NEO4J_AUTHENTICATION_USERNAME = local.neo4j.username
    SPRING_NEO4J_AUTHENTICATION_PASSWORD = local.neo4j.password
    JWT_SECRET                           = local.jwt.jwt_secret
    QR_SECRET                            = local.jwt.qr_secret
    TWILIO_ACCOUNT_SID                   = local.twilio.account_sid
    TWILIO_AUTH_TOKEN                    = local.twilio.auth_token
    VAULT_SECRET                         = local.vault.secret
    VAULT_SALT                           = local.vault.salt
    VAULT_HASH_SALT                      = local.vault.hash_salt
    LDAP_ADMIN_PASSWORD                  = local.ldap.admin_password
  }
}
