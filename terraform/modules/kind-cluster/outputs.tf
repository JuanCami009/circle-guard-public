output "kubeconfig_path" {
  description = "Path to the kubeconfig file written to disk"
  value       = local_file.kubeconfig.filename
}

output "kubeconfig" {
  description = "Raw kubeconfig string for the cluster. Sensitive — parse with yamldecode if individual fields are needed."
  value       = kind_cluster.this.kubeconfig
  sensitive   = true
}

output "endpoint" {
  description = "Kubernetes API server endpoint"
  value       = kind_cluster.this.endpoint
}

output "client_certificate" {
  description = "Client certificate for authenticating to the cluster (base64-encoded)"
  value       = kind_cluster.this.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Client key for authenticating to the cluster (base64-encoded)"
  value       = kind_cluster.this.client_key
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate used to verify the server (base64-encoded)"
  value       = kind_cluster.this.cluster_ca_certificate
  sensitive   = true
}
