variable "namespace" {
  type        = string
  description = "Kubernetes namespace where neo4j resources will be deployed."
}

variable "image" {
  type        = string
  default     = "neo4j:5.26"
  description = "Neo4j container image."
}

variable "nodeport_browser" {
  type        = number
  description = "NodePort for the Neo4j Browser (HTTP 7474) external access."
}

variable "auth_secret_name" {
  type        = string
  description = "Name of the Kubernetes Secret containing NEO4J_AUTH credentials. Set to empty string to use the default plaintext value."
  default     = ""
}

variable "resources" {
  type = object({
    requests = map(string)
    limits   = map(string)
  })
  default = {
    requests = { memory = "256Mi", cpu = "200m" }
    limits   = { memory = "768Mi", cpu = "1000m" }
  }
  description = "CPU/memory resource requests and limits for the neo4j container."
}
