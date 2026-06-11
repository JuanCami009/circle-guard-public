variable "env" {
  type    = string
  default = "dev"
}

variable "namespace" {
  type    = string
  default = "circleguard-dev"
}

variable "image_tag" {
  type    = string
  default = "dev"
}

variable "nodeport_base" {
  type    = number
  default = 31000
}

variable "replicas" {
  type    = number
  default = 1
}

variable "enable_elk" {
  type        = bool
  default     = false
  description = "Deploy ELK stack (Elasticsearch, Logstash, Kibana, Filebeat). Disable to save ~2 GB on local kind clusters."
}

variable "localstack_host" {
  type        = string
  default     = "localhost"
  description = "LocalStack hostname. 'localhost' when running from Mac; 'host.docker.internal' when running inside Jenkins/Docker."
}
