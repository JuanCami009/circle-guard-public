output "host" {
  description = "Redis hostname within the cluster (SPRING_DATA_REDIS_HOST)."
  value       = "redis-svc"
}

output "port" {
  description = "Redis port."
  value       = 6379
}
