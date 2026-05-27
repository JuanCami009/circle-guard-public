variable "name" {
  description = "Service name, e.g. 'auth-service'"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace to deploy into"
  type        = string
}

variable "image" {
  description = "Container image name without tag, e.g. 'circleguard/auth-service'"
  type        = string
}

variable "image_tag" {
  description = "Container image tag"
  type        = string
  default     = "latest"
}

variable "image_pull_policy" {
  description = "Image pull policy — 'Never' for kind (local images), 'Always' for remote registries"
  type        = string
  default     = "Never"
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
}

variable "nodeport" {
  description = "NodePort to expose (3xxxx range); ignored when service_type != NodePort"
  type        = number
}

variable "service_type" {
  description = "Kubernetes Service type: NodePort or ClusterIP"
  type        = string
  default     = "NodePort"
}

variable "replicas" {
  description = "Number of pod replicas"
  type        = number
  default     = 1
}

variable "resources" {
  description = "CPU and memory requests/limits for the main container"
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = { memory = "256Mi", cpu = "100m" }
    limits   = { memory = "512Mi", cpu = "500m" }
  }
}

variable "config_map_ref" {
  description = "Name of ConfigMap to load via envFrom (null to skip)"
  type        = string
  default     = null
}

variable "secret_ref" {
  description = "Name of Secret to load via envFrom (null to skip)"
  type        = string
  default     = null
}

variable "extra_env" {
  description = "Additional env vars (name → value) applied after envFrom blocks"
  type        = map(string)
  default     = {}
}

variable "init_wait_for" {
  description = "Services to wait for before starting (rendered as busybox nc -z initContainers)"
  type = list(object({
    name = string # e.g. "wait-for-postgres"
    host = string # e.g. "postgres-svc"
    port = number # e.g. 5432
  }))
  default = []
}

variable "volume_mounts" {
  description = "Additional volume mounts (e.g. for file-service uploads directory)"
  type = list(object({
    name       = string
    mount_path = string
    read_only  = optional(bool, false)
  }))
  default = []
}

variable "volumes" {
  description = "Additional volumes matching volume_mounts (only 'emptyDir' type supported)"
  type = list(object({
    name = string
    type = string # "emptyDir"
  }))
  default = []
}
