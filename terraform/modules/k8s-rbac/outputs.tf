output "service_account_names" {
  description = "Map of service name → ServiceAccount name (e.g. { \"auth-service\" = \"auth-service-sa\" })"
  value       = { for name in var.service_names : name => kubernetes_service_account_v1.microservices[name].metadata[0].name }
}
