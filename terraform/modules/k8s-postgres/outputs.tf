output "service_name" {
  description = "Name of the postgres ClusterIP service."
  value       = kubernetes_service_v1.postgres_svc.metadata[0].name
}

output "port" {
  description = "PostgreSQL port exposed by the service."
  value       = 5432
}
