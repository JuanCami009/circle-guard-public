output "host" {
  description = "Internal ClusterIP hostname for Zipkin (used by Spring services as tracing endpoint)."
  value       = "zipkin-svc"
}

output "port" {
  value = 9411
}

output "ui_url" {
  description = "Zipkin UI URL accessible from the host via NodePort."
  value       = "http://localhost:${var.nodeport_ui}"
}
