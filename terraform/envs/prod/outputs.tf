output "kubeconfig_path" {
  value = module.cluster.kubeconfig_path
}

output "gateway_url" {
  value = "http://localhost:${var.nodeport_base + 87}"
}

output "auth_url" {
  value = "http://localhost:${var.nodeport_base + 180}"
}

output "mailhog_url" {
  value = "http://localhost:${var.nodeport_base + 25}"
}
