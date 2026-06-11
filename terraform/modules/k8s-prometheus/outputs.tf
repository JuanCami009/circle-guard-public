output "host" {
  description = "Internal ClusterIP hostname for Prometheus (used by Grafana datasource)."
  value       = "prometheus-svc"
}

output "port" {
  value = 9090
}

output "ui_url" {
  description = "Prometheus UI URL accessible from the host via NodePort."
  value       = "http://localhost:${var.nodeport_ui}"
}
