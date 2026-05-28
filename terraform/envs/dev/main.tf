# ── 1. kind cluster ────────────────────────────────────────────────────────────
module "cluster" {
  source = "../../modules/kind-cluster"
  name   = "circleguard-${var.env}"
  extra_port_mappings = [
    # auth=+180, identity=+83, promotion=+88, notification=+82, form=+86,
    # file=+85, gateway=+87, dashboard=+84, neo4j browser=+474, mailhog UI=+25
    { container_port = var.nodeport_base + 180, host_port = var.nodeport_base + 180 },
    { container_port = var.nodeport_base + 83,  host_port = var.nodeport_base + 83  },
    { container_port = var.nodeport_base + 88,  host_port = var.nodeport_base + 88  },
    { container_port = var.nodeport_base + 82,  host_port = var.nodeport_base + 82  },
    { container_port = var.nodeport_base + 86,  host_port = var.nodeport_base + 86  },
    { container_port = var.nodeport_base + 85,  host_port = var.nodeport_base + 85  },
    { container_port = var.nodeport_base + 87,  host_port = var.nodeport_base + 87  },
    { container_port = var.nodeport_base + 84,  host_port = var.nodeport_base + 84  },
    { container_port = var.nodeport_base + 474, host_port = var.nodeport_base + 474 }, # neo4j browser
    { container_port = var.nodeport_base + 25,  host_port = var.nodeport_base + 25  }, # mailhog UI
  ]
}

# ── 2. Namespace ───────────────────────────────────────────────────────────────
module "ns" {
  source    = "../../modules/k8s-namespaces"
  namespace = var.namespace
  labels    = { env = var.env, "managed-by" = "terraform" }
  depends_on = [module.cluster]
}

# ── 3. AWS resources (LocalStack) ─────────────────────────────────────────────
module "s3_uploads" {
  source            = "../../modules/aws-s3-uploads"
  bucket_name       = "circleguard-uploads-${var.env}"
  force_destroy     = true
  versioning_status = "Suspended"
  tags              = { Environment = var.env, ManagedBy = "terraform" }
}

module "secrets" {
  source = "../../modules/aws-secrets"
  env    = var.env
  secrets = {
    jwt = {
      description = "JWT and QR signing secrets"
      value       = jsonencode({ jwt_secret = "my-super-secret-dev-key-32-chars-long-12345678", qr_secret = "my-qr-secret-key-for-dev-1234567890" })
    }
    postgres = {
      description = "PostgreSQL credentials"
      value       = jsonencode({ username = "admin", password = "password" })
    }
    neo4j = {
      description = "Neo4j credentials"
      value       = jsonencode({ username = "neo4j", password = "password" })
    }
    twilio = {
      description = "Twilio SMS credentials (dev placeholders)"
      value       = jsonencode({ account_sid = "dev_placeholder", auth_token = "dev_placeholder" })
    }
    vault = {
      description = "Identity service vault secrets"
      value       = jsonencode({ secret = "my-vault-secret-key-32-chars-1234", salt = "deadbeef", hash_salt = "12345678" })
    }
    ldap = {
      description = "OpenLDAP admin credentials"
      value       = jsonencode({ admin_password = "admin" })
    }
  }
}

# ── 4. k8s ConfigMap + Secret ──────────────────────────────────────────────────
module "config" {
  source      = "../../modules/k8s-config"
  namespace   = module.ns.name
  secret_arns = module.secrets.secret_arns
  config_map_data = {
    SPRING_DATA_REDIS_HOST                           = "redis-svc"
    SPRING_DATA_REDIS_PORT                           = "6379"
    SPRING_KAFKA_BOOTSTRAP_SERVERS                   = "kafka-svc:9092"
    SPRING_NEO4J_URI                                 = "bolt://neo4j-svc:7687"
    JWT_EXPIRATION                                   = "3600000"
    QR_EXPIRATION                                    = "300"
    AUTH_API_URL                                     = "http://auth-service-svc:8180"
    SPRING_KAFKA_LISTENER_MISSING_TOPICS_FATAL       = "false"
    SPRING_DATA_REDIS_REPOSITORIES_ENABLED           = "false"
    SPRING_MAIL_HOST                                 = "mailhog-svc"
    SPRING_MAIL_PORT                                 = "1025"
    SPRING_MAIL_PROPERTIES_MAIL_SMTP_AUTH            = "false"
    SPRING_MAIL_PROPERTIES_MAIL_SMTP_STARTTLS_ENABLE = "false"
    SPRING_DATASOURCE_DRIVER_CLASS_NAME              = "org.postgresql.Driver"
    SPRING_JPA_HIBERNATE_DDL_AUTO                    = "update"
    SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT          = "org.hibernate.dialect.PostgreSQLDialect"
  }
  depends_on = [module.ns, module.secrets]
}

# ── 5. Infrastructure services ─────────────────────────────────────────────────
module "postgres" {
  source      = "../../modules/k8s-postgres"
  namespace   = module.ns.name
  secret_name = module.config.secret_name
  depends_on  = [module.config]
}

module "neo4j" {
  source           = "../../modules/k8s-neo4j"
  namespace        = module.ns.name
  nodeport_browser = var.nodeport_base + 474
  auth_secret_name = "" # uses plaintext neo4j/password
  depends_on       = [module.ns]
}

module "kafka" {
  source     = "../../modules/k8s-kafka"
  namespace  = module.ns.name
  depends_on = [module.ns]
}

module "redis" {
  source     = "../../modules/k8s-redis"
  namespace  = module.ns.name
  depends_on = [module.ns]
}

module "openldap" {
  source     = "../../modules/k8s-openldap"
  namespace  = module.ns.name
  depends_on = [module.ns]
}

module "mailhog" {
  source       = "../../modules/k8s-mailhog"
  namespace    = module.ns.name
  nodeport_ui  = var.nodeport_base + 25
  depends_on   = [module.ns]
}

# ── 6. Microservices ───────────────────────────────────────────────────────────
locals {
  services = {
    "auth-service" = {
      port = 8180
      np   = var.nodeport_base + 180
      init = [
        { name = "wait-for-postgres", host = "postgres-svc", port = 5432 },
        { name = "wait-for-ldap",     host = "openldap-svc",  port = 389 },
      ]
      extra_env = {
        SERVER_PORT           = "8180"
        SPRING_DATASOURCE_URL = "jdbc:postgresql://postgres-svc:5432/circleguard_auth"
        SPRING_LDAP_URLS      = "ldap://openldap-svc:389"
        SPRING_LDAP_BASE      = "dc=circleguard,dc=edu"
        SPRING_LDAP_USERNAME  = "cn=admin,dc=circleguard,dc=edu"
        SPRING_LDAP_PASSWORD  = "admin"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
    "identity-service" = {
      port = 8083
      np   = var.nodeport_base + 83
      init = [
        { name = "wait-for-postgres", host = "postgres-svc", port = 5432 },
      ]
      extra_env = {
        SERVER_PORT           = "8083"
        SPRING_DATASOURCE_URL = "jdbc:postgresql://postgres-svc:5432/circleguard_identity"
        VAULT_SECRET          = "my-vault-secret-key-32-chars-1234"
        VAULT_SALT            = "deadbeef"
        VAULT_HASH_SALT       = "12345678"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
    "promotion-service" = {
      port = 8088
      np   = var.nodeport_base + 88
      init = [
        { name = "wait-for-neo4j",    host = "neo4j-svc",    port = 7687 },
        { name = "wait-for-kafka",    host = "kafka-svc",    port = 9092 },
        { name = "wait-for-postgres", host = "postgres-svc", port = 5432 },
      ]
      extra_env = {
        SERVER_PORT           = "8088"
        SPRING_DATASOURCE_URL = "jdbc:postgresql://postgres-svc:5432/circleguard_promotion"
      }
      resources = {
        requests = { memory = "512Mi", cpu = "200m" }
        limits   = { memory = "1Gi", cpu = "1000m" }
      }
    }
    "notification-service" = {
      port = 8082
      np   = var.nodeport_base + 82
      init = [
        { name = "wait-for-kafka", host = "kafka-svc", port = 9092 },
      ]
      extra_env = {
        SERVER_PORT = "8082"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
    "form-service" = {
      port = 8086
      np   = var.nodeport_base + 86
      init = []
      extra_env = {
        SERVER_PORT           = "8086"
        SPRING_DATASOURCE_URL = "jdbc:postgresql://postgres-svc:5432/circleguard_form"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
    "file-service" = {
      port = 8085
      np   = var.nodeport_base + 85
      init = []
      extra_env = {
        SERVER_PORT = "8085"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
    "gateway-service" = {
      port = 8087
      np   = var.nodeport_base + 87
      init = []
      extra_env = {
        SERVER_PORT = "8087"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
    "dashboard-service" = {
      port = 8084
      np   = var.nodeport_base + 84
      init = []
      extra_env = {
        SERVER_PORT           = "8084"
        SPRING_DATASOURCE_URL = "jdbc:postgresql://postgres-svc:5432/circleguard_dashboard"
      }
      resources = {
        requests = { memory = "256Mi", cpu = "100m" }
        limits   = { memory = "512Mi", cpu = "500m" }
      }
    }
  }
}

module "services" {
  for_each = local.services
  source   = "../../modules/k8s-microservice"

  name           = each.key
  namespace      = module.ns.name
  image          = "circleguard/${each.key}"
  image_tag      = var.image_tag
  container_port = each.value.port
  nodeport       = each.value.np
  replicas       = var.replicas
  resources      = each.value.resources
  config_map_ref = module.config.config_map_name
  secret_ref     = module.config.secret_name
  extra_env      = each.value.extra_env
  init_wait_for  = each.value.init

  # file-service needs a persistent uploads volume
  volume_mounts = each.key == "file-service" ? [{ name = "uploads", mount_path = "/app/uploads", read_only = false }] : []
  volumes       = each.key == "file-service" ? [{ name = "uploads", type = "emptyDir" }] : []

  depends_on = [module.config, module.postgres, module.neo4j, module.kafka, module.redis, module.openldap, module.mailhog]
}
