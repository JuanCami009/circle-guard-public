variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Kibana resources will be deployed."
}

variable "image" {
  type        = string
  default     = "docker.elastic.co/kibana/kibana:8.13.4"
  description = "Kibana container image."
}

variable "nodeport_ui" {
  type        = number
  description = "NodePort for exposing Kibana UI on the host."
}

variable "elasticsearch_url" {
  type        = string
  default     = "http://elasticsearch-svc:9200"
  description = "Elasticsearch endpoint Kibana connects to."
}
