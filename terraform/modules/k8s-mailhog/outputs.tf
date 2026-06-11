output "smtp_host" {
  description = "SMTP hostname for notification-service (SPRING_MAIL_HOST)."
  value       = "mailhog-svc"
}

output "smtp_port" {
  description = "SMTP port for notification-service (SPRING_MAIL_PORT)."
  value       = 1025
}

output "ui_url" {
  description = "MailHog web UI URL accessible from the host via NodePort."
  value       = "http://localhost:${var.nodeport_ui}"
}
