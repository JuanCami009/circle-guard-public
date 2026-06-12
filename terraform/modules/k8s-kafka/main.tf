# ---------------------------------------------------------------------------
# Helm path (default): bitnami/kafka with ZooKeeper bundled, KRaft disabled.
# fullnameOverride = "kafka-svc" ensures the broker service is named kafka-svc
# so that the existing ConfigMap entry SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka-svc:9092
# continues to work without changes.
# ---------------------------------------------------------------------------

resource "helm_release" "kafka" {
  count = var.use_helm ? 1 : 0

  name       = "kafka"
  chart      = "kafka"
  repository = "https://charts.bitnami.com/bitnami"
  version    = var.chart_version
  namespace  = var.namespace

  wait    = true
  timeout = 600

  set {
    name  = "kraft.enabled"
    value = "false"
  }

  set {
    name  = "zookeeper.enabled"
    value = "true"
  }

  # bitnami/kafka ≥26: brokers configured via broker.replicaCount in Zookeeper mode
  set {
    name  = "broker.replicaCount"
    value = tostring(var.replicas)
  }

  # Must be 0 in Zookeeper mode — controller nodes are KRaft-only
  set {
    name  = "controller.replicaCount"
    value = "0"
  }

  # Disable persistence — kind clusters have no fast dynamic storage provisioner;
  # PVC binding stalls pods and causes the 300s timeout.
  set {
    name  = "broker.persistence.enabled"
    value = "false"
  }

  set {
    name  = "zookeeper.persistence.enabled"
    value = "false"
  }

  # Makes the broker headless + client service names start with "kafka-svc"
  # so existing app config (kafka-svc:9092) resolves correctly.
  set {
    name  = "fullnameOverride"
    value = "kafka-svc"
  }

  set {
    name  = "listeners.client.protocol"
    value = "PLAINTEXT"
  }

  set {
    name  = "externalAccess.enabled"
    value = "false"
  }
}

# ---------------------------------------------------------------------------
# Raw fallback path (use_helm = false): raw Kubernetes resources that mirror
# k8s/infra/05-zookeeper.yml + k8s/infra/06-kafka.yml exactly.
# ---------------------------------------------------------------------------

# --- ZooKeeper ---

resource "kubernetes_deployment_v1" "zookeeper" {
  wait_for_rollout = false
  count = var.use_helm ? 0 : 1

  metadata {
    name      = "zookeeper"
    namespace = var.namespace
    labels = {
      app = "zookeeper"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "zookeeper"
      }
    }

    template {
      metadata {
        labels = {
          app = "zookeeper"
        }
      }

      spec {
        container {
          name  = "zookeeper"
          image = "confluentinc/cp-zookeeper:7.6.0"

          port {
            container_port = 2181
          }

          env {
            name  = "ZOOKEEPER_CLIENT_PORT"
            value = "2181"
          }

          env {
            name  = "ZOOKEEPER_TICK_TIME"
            value = "2000"
          }

          env {
            name  = "ZOOKEEPER_HEAP_OPTS"
            value = "-Xms64m -Xmx128m"
          }

          readiness_probe {
            exec {
              command = ["nc", "-z", "localhost", "2181"]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          resources {
            requests = { memory = "128Mi", cpu = "50m" }
            limits   = { memory = "256Mi", cpu = "200m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "zookeeper_svc" {
  count = var.use_helm ? 0 : 1

  metadata {
    name      = "zookeeper-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "zookeeper"
    }

    port {
      port        = 2181
      target_port = 2181
    }

    type = "ClusterIP"
  }
}

# --- Kafka broker ---

resource "kubernetes_deployment_v1" "kafka" {
  wait_for_rollout = false
  count = var.use_helm ? 0 : 1

  metadata {
    name      = "kafka"
    namespace = var.namespace
    labels = {
      app = "kafka"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        container {
          name  = "kafka"
          image = "confluentinc/cp-kafka:7.6.0"

          port {
            container_port = 9092
          }

          env {
            name  = "KAFKA_BROKER_ID"
            value = "1"
          }

          env {
            name  = "KAFKA_ZOOKEEPER_CONNECT"
            value = "zookeeper-svc:2181"
          }

          # CRITICAL: must use the K8s Service DNS name so pods can reach the
          # broker via DNS resolution (not localhost).
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "PLAINTEXT://kafka-svc:9092"
          }

          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "PLAINTEXT:PLAINTEXT"
          }

          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "PLAINTEXT"
          }

          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "1"
          }

          env {
            name  = "KAFKA_AUTO_CREATE_TOPICS_ENABLE"
            value = "true"
          }

          env {
            name  = "KAFKA_HEAP_OPTS"
            value = "-Xms128m -Xmx256m"
          }

          resources {
            requests = { memory = "256Mi", cpu = "100m" }
            limits   = { memory = "512Mi", cpu = "500m" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "kafka_svc" {
  count = var.use_helm ? 0 : 1

  metadata {
    name      = "kafka-svc"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "kafka"
    }

    port {
      port        = 9092
      target_port = 9092
    }

    type = "ClusterIP"
  }
}
