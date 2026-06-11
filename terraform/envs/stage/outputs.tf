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

# ── Observabilidad (Punto 7) ──────────────────────────────────────────────────
output "prometheus_url" {
  description = "Prometheus UI (targets, graph, alerts)"
  value       = module.prometheus.ui_url
}

output "grafana_url" {
  description = "Grafana UI — admin / circleguard"
  value       = module.grafana.ui_url
}

output "kibana_url" {
  description = "Kibana UI — explorador de logs"
  value       = module.kibana.ui_url
}

output "zipkin_url" {
  description = "Zipkin UI — trazas distribuidas"
  value       = module.zipkin.ui_url
}

output "alertmanager_url" {
  description = "Alertmanager UI — alertas activas"
  value       = module.alertmanager.ui_url
}

# ── Seguridad (Punto 8) ───────────────────────────────────────────────────────
output "gateway_https_url" {
  description = "Gateway HTTPS vía ingress-nginx (añadir '127.0.0.1 circleguard.local' a /etc/hosts)"
  value       = module.ingress.https_url
}
