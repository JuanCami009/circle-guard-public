output "host" {
  description = "Internal ClusterIP hostname for Elasticsearch."
  value       = "elasticsearch-svc"
}

output "port" {
  value = 9200
}
