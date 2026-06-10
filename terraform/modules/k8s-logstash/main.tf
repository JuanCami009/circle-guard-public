# ---------------------------------------------------------------------------
# Logstash — receives Beats input from Filebeat and forwards to Elasticsearch.
# Pipeline: input beats:5044 → filter grok/json → output elasticsearch.
# ---------------------------------------------------------------------------

resource "kubernetes_config_map_v1" "logstash_pipeline" {
  metadata {
    name      = "logstash-pipeline"
    namespace = var.namespace
  }

  data = {
    "circleguard.conf" = <<-CONF
      input {
        beats {
          port => 5044
        }
      }

      filter {
        # The services log JSON via LogstashEncoder; parse it directly
        if [message] =~ /^\{/ {
          json {
            source  => "message"
            target  => "parsed"
          }
          mutate {
            rename => {
              "[parsed][level]"       => "level"
              "[parsed][message]"     => "log_message"
              "[parsed][traceId]"     => "trace_id"
              "[parsed][spanId]"      => "span_id"
              "[parsed][logger_name]" => "logger"
              "[parsed][thread_name]" => "thread"
            }
          }
        }
        # Fallback: plain-text log line kept as-is

        mutate {
          # Ensure index-friendly field names
          add_field => { "[@metadata][index]" => "circleguard-logs-%%{+YYYY.MM.dd}" }
        }
      }

      output {
        elasticsearch {
          hosts     => ["${var.elasticsearch_url}"]
          index     => "%%{[@metadata][index]}"
        }
      }
    CONF
  }
}

resource "kubernetes_deployment_v1" "logstash" {
  metadata {
    name      = "logstash"
    namespace = var.namespace
    labels    = { app = "logstash" }
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = "logstash" }
    }

    template {
      metadata {
        labels = { app = "logstash" }
      }

      spec {
        container {
          name  = "logstash"
          image = var.image

          port {
            container_port = 5044
            name           = "beats"
          }

          env {
            name  = "LS_JAVA_OPTS"
            value = "-Xmx512m -Xms512m"
          }

          volume_mount {
            name       = "pipeline"
            mount_path = "/usr/share/logstash/pipeline"
            read_only  = true
          }

          resources {
            requests = { memory = "512Mi", cpu = "200m" }
            limits   = { memory = "1Gi",  cpu = "500m" }
          }
        }

        volume {
          name = "pipeline"
          config_map {
            name = kubernetes_config_map_v1.logstash_pipeline.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "logstash_svc" {
  metadata {
    name      = "logstash-svc"
    namespace = var.namespace
  }

  spec {
    selector = { app = "logstash" }
    type     = "ClusterIP"
    port {
      name        = "beats"
      port        = 5044
      target_port = 5044
    }
  }
}
