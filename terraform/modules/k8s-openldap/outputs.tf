output "ldap_url" {
  description = "LDAP URL for auth-service DualChainAuthenticationProvider."
  value       = "ldap://openldap-svc:389"
}

output "base_dn" {
  description = "LDAP base DN derived from var.domain (e.g. circleguard.edu → dc=circleguard,dc=edu)."
  value       = "dc=${replace(var.domain, ".", ",dc=")}"
}
