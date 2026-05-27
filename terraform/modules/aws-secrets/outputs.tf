output "secret_arns" {
  description = "Map of secret slug → ARN"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
  sensitive   = true
}

output "secret_names" {
  description = "Map of secret slug → full name"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.name }
  sensitive   = true
}
