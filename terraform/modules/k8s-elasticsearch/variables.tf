variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Elasticsearch resources will be deployed."
}

variable "image" {
  type        = string
  default     = "docker.elastic.co/elasticsearch/elasticsearch:8.13.4"
  description = "Elasticsearch container image."
}
