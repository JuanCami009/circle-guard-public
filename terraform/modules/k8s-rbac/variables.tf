variable "namespace" {
  description = "Kubernetes namespace where namespaced resources (Roles, RoleBindings, ServiceAccounts) are created"
  type        = string
}

variable "service_names" {
  description = "List of microservice names to create dedicated ServiceAccounts for (e.g. [\"auth-service\", \"gateway-service\"])"
  type        = list(string)
}
