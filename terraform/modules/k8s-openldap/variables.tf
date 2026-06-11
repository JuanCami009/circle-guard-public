variable "namespace" {
  type        = string
  description = "Kubernetes namespace where OpenLDAP resources will be deployed."
}

variable "image" {
  type        = string
  default     = "osixia/openldap:1.5.0"
  description = "OpenLDAP container image."
}

variable "organisation" {
  type        = string
  default     = "CircleGuard"
  description = "LDAP organisation name (LDAP_ORGANISATION)."
}

variable "domain" {
  type        = string
  default     = "circleguard.edu"
  description = "LDAP domain (LDAP_DOMAIN). Used to derive the base DN."
}

variable "admin_password" {
  type        = string
  default     = "admin"
  sensitive   = true
  description = "LDAP admin password (LDAP_ADMIN_PASSWORD)."
}
