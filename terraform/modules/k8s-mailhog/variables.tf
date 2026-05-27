variable "namespace" {
  type        = string
  description = "Kubernetes namespace where MailHog resources will be deployed."
}

variable "image" {
  type        = string
  default     = "mailhog/mailhog:latest"
  description = "MailHog container image."
}

variable "nodeport_ui" {
  type        = number
  default     = 30025
  description = "NodePort for exposing the MailHog web UI on the host (http://localhost:<nodeport_ui>)."
}
