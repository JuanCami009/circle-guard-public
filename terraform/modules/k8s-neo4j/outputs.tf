output "bolt_uri" {
  description = "Bolt URI for Spring Boot neo4j driver configuration."
  value       = "bolt://neo4j-svc:7687"
}

output "http_url" {
  description = "HTTP URL for Neo4j Browser access within the cluster."
  value       = "http://neo4j-svc:7474"
}
