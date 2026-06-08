variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Prometheus resources will be deployed."
}

variable "image" {
  type        = string
  default     = "prom/prometheus:v2.51.2"
  description = "Prometheus container image."
}

variable "nodeport_ui" {
  type        = number
  description = "NodePort for exposing Prometheus UI on the host (http://localhost:<nodeport_ui>)."
}

variable "alertmanager_url" {
  type        = string
  default     = "http://alertmanager-svc:9093"
  description = "Alertmanager endpoint Prometheus sends alerts to."
}
