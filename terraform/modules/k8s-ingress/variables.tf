variable "namespace" {
  description = "Kubernetes namespace where the TLS Secret and Ingress resource are created"
  type        = string
}

variable "nodeport_http" {
  description = "NodePort for HTTP traffic on the ingress-nginx controller (e.g. 31080)"
  type        = number
}

variable "nodeport_https" {
  description = "NodePort for HTTPS traffic on the ingress-nginx controller (e.g. 31443)"
  type        = number
}

variable "gateway_service_name" {
  description = "ClusterIP Service name of the gateway-service backend"
  type        = string
  default     = "gateway-service-svc"
}

variable "gateway_port" {
  description = "Port of the gateway-service backend"
  type        = number
  default     = 8087
}

variable "tls_secret_name" {
  description = "Name of the kubernetes.io/tls Secret to create"
  type        = string
  default     = "circleguard-tls"
}

variable "ingress_host" {
  description = "Hostname used in the Ingress rule and TLS certificate CN"
  type        = string
  default     = "circleguard.local"
}
