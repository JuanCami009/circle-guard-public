variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "config_map_data" {
  description = "Data for the circleguard-config ConfigMap"
  type        = map(string)
}

variable "secret_arns" {
  description = "Map of secret slug → ARN in AWS Secrets Manager (from aws-secrets module)"
  type        = map(string)
  sensitive   = true
}
