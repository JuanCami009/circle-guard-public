variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Kafka resources will be deployed."
}

variable "use_helm" {
  type        = bool
  default     = true
  description = "When true, deploy Kafka via bitnami/kafka Helm chart. When false, use raw Kubernetes manifests (Confluent images)."
}

variable "chart_version" {
  type        = string
  default     = "30.1.8"
  description = "Bitnami kafka Helm chart version (ZooKeeper-based, KRaft disabled)."
}

variable "replicas" {
  type        = number
  default     = 1
  description = "Number of Kafka broker replicas."
}
