output "host" {
  description = "Internal ClusterIP hostname for Logstash Beats input."
  value       = "logstash-svc"
}

output "beats_port" {
  value = 5044
}
