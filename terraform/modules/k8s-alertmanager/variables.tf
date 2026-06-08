variable "namespace" {
  type        = string
  description = "Kubernetes namespace where Alertmanager resources will be deployed."
}

variable "image" {
  type        = string
  default     = "prom/alertmanager:v0.27.0"
  description = "Alertmanager container image."
}

variable "nodeport_ui" {
  type        = number
  description = "NodePort for exposing Alertmanager UI on the host."
}

variable "smtp_host" {
  type        = string
  default     = "mailhog-svc:1025"
  description = "SMTP host:port for sending alert emails (default: MailHog)."
}

variable "smtp_from" {
  type        = string
  default     = "alertmanager@circleguard.local"
  description = "From address for alert emails."
}

variable "alert_receiver_email" {
  type        = string
  default     = "ops@circleguard.local"
  description = "Email address that receives alerts."
}
