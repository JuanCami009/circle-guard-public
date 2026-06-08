output "host" {
  description = "Internal ClusterIP hostname for Alertmanager (used by Prometheus alerting block)."
  value       = "alertmanager-svc"
}

output "port" {
  value = 9093
}

output "ui_url" {
  description = "Alertmanager UI URL accessible from the host via NodePort."
  value       = "http://localhost:${var.nodeport_ui}"
}
