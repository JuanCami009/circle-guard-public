variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Logstash resources will be deployed."
}

variable "image" {
  type        = string
  default     = "docker.elastic.co/logstash/logstash:8.13.4"
  description = "Logstash container image."
}

variable "elasticsearch_url" {
  type        = string
  default     = "http://elasticsearch-svc:9200"
  description = "Elasticsearch endpoint Logstash outputs logs to."
}
