output "service_dns" {
  description = "In-cluster DNS name for this service"
  value       = "${var.name}-svc.${var.namespace}.svc.cluster.local"
}

output "nodeport_url" {
  description = "URL reachable from the host when service_type = NodePort (kind port-mapping)"
  value       = "http://localhost:${var.nodeport}"
}
