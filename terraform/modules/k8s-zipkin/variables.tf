variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Zipkin resources will be deployed."
}

variable "image" {
  type        = string
  default     = "openzipkin/zipkin:3.3"
  description = "Zipkin container image."
}

variable "nodeport_ui" {
  type        = number
  description = "NodePort for exposing Zipkin UI on the host."
}
