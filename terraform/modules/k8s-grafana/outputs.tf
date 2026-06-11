output "host" {
  description = "Internal ClusterIP hostname for Grafana."
  value       = "grafana-svc"
}

output "port" {
  value = 3000
}

output "ui_url" {
  description = "Grafana UI URL accessible from the host via NodePort."
  value       = "http://localhost:${var.nodeport_ui}"
}
