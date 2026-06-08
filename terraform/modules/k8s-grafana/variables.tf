variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Grafana resources will be deployed."
}

variable "image" {
  type        = string
  default     = "grafana/grafana:10.4.2"
  description = "Grafana container image."
}

variable "nodeport_ui" {
  type        = number
  description = "NodePort for exposing Grafana UI on the host (http://localhost:<nodeport_ui>)."
}

variable "prometheus_url" {
  type        = string
  default     = "http://prometheus-svc:9090"
  description = "Prometheus datasource URL (internal ClusterIP)."
}

variable "elasticsearch_url" {
  type        = string
  default     = "http://elasticsearch-svc:9200"
  description = "Elasticsearch datasource URL (internal ClusterIP)."
}

variable "zipkin_url" {
  type        = string
  default     = "http://zipkin-svc:9411"
  description = "Zipkin datasource URL (Tempo-compatible endpoint, internal ClusterIP)."
}

variable "admin_password" {
  type        = string
  default     = "circleguard"
  description = "Grafana admin password."
  sensitive   = true
}
