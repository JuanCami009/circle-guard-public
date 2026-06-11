variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Redis resources will be deployed."
}

variable "chart_version" {
  type        = string
  default     = "19.6.4"
  description = "Bitnami redis Helm chart version."
}

variable "architecture" {
  type        = string
  default     = "standalone"
  description = "Redis deployment architecture. Supported values: standalone, replication."
}
