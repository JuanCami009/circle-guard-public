output "config_map_name" {
  description = "Name of the ConfigMap"
  value       = kubernetes_config_map_v1.circleguard_config.metadata[0].name
}

output "secret_name" {
  description = "Name of the Kubernetes secret"
  value       = kubernetes_secret_v1.circleguard_secrets.metadata[0].name
  sensitive   = true
}
