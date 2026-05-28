variable "namespace" {
  type        = string
  description = "Kubernetes namespace where postgres resources will be deployed."
}

variable "image" {
  type        = string
  default     = "postgres:16"
  description = "PostgreSQL container image."
}

variable "databases" {
  type        = list(string)
  default     = ["circleguard_auth", "circleguard_identity", "circleguard_promotion", "circleguard_dashboard", "circleguard_form"]
  description = "List of databases to create on first boot via init-db.sql."
}

variable "secret_name" {
  type        = string
  description = "Name of the Kubernetes Secret containing POSTGRES_USER and POSTGRES_PASSWORD keys."
}

variable "resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = { memory = "256Mi", cpu = "100m" }
    limits   = { memory = "512Mi", cpu = "500m" }
  }
  description = "CPU/memory resource requests and limits for the postgres container."
}
