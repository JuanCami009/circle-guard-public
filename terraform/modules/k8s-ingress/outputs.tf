output "https_url" {
  description = "HTTPS URL via ingress-nginx NodePort (add circleguard.local to /etc/hosts pointing to 127.0.0.1)"
  value       = "https://localhost:${var.nodeport_https}"
}

output "http_url" {
  description = "HTTP URL via ingress-nginx NodePort (redirects to HTTPS)"
  value       = "http://localhost:${var.nodeport_http}"
}

output "tls_secret_name" {
  description = "Name of the kubernetes.io/tls Secret created for the Ingress"
  value       = kubernetes_secret_v1.tls.metadata[0].name
}
