output "host" {
  description = "Internal ClusterIP hostname for Kibana."
  value       = "kibana-svc"
}

output "port" {
  value = 5601
}

output "ui_url" {
  description = "Kibana UI URL accessible from the host via NodePort."
  value       = "http://localhost:${var.nodeport_ui}"
}
