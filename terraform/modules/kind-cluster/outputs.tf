output "kubeconfig_path" {
  description = "Path to the kubeconfig file written to disk"
  value       = local_file.kubeconfig.filename
}

output "kubeconfig" {
  description = "Raw kubeconfig string for the cluster"
  value       = local.kubeconfig_fixed
  sensitive   = true
}

output "endpoint" {
  description = "Kubernetes API server endpoint"
  value       = local.endpoint
}

output "client_certificate" {
  description = "Client certificate for authenticating to the cluster (base64-encoded)"
  value       = local.kube.users[0].user["client-certificate-data"]
  sensitive   = true
}

output "client_key" {
  description = "Client key for authenticating to the cluster (base64-encoded)"
  value       = local.kube.users[0].user["client-key-data"]
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Cluster CA certificate (base64-encoded)"
  value       = local.kube.clusters[0].cluster["certificate-authority-data"]
  sensitive   = true
}
