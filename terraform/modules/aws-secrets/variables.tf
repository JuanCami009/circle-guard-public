variable "env" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "secrets" {
  description = "Map of secret slug → object with description and JSON value string"
  type = map(object({
    description = string
    value       = string
  }))
  sensitive = true
}
