variable "name" {
  description = "Name of the kind cluster"
  type        = string
}

variable "node_image" {
  description = "Kindest node image"
  type        = string
  default     = "kindest/node:v1.30.0"
}

variable "extra_port_mappings" {
  description = "Host port mappings to expose from the cluster node"
  type = list(object({
    container_port = number
    host_port      = number
    protocol       = optional(string, "TCP")
  }))
  default = []
}

variable "wait_for_ready" {
  description = "Whether to wait for cluster nodes to be ready"
  type        = bool
  default     = true
}
