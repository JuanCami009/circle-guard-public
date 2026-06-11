variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Filebeat DaemonSet and RBAC will be deployed."
}

variable "image" {
  type        = string
  default     = "docker.elastic.co/beats/filebeat:8.13.4"
  description = "Filebeat container image."
}

variable "logstash_host" {
  type        = string
  default     = "logstash-svc:5044"
  description = "Logstash Beats input host:port."
}
