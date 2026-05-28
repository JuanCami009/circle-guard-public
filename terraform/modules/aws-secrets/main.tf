resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name            = "circleguard/${var.env}/${each.key}"
  description     = each.value.description

  tags = {
    Environment = var.env
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id      = aws_secretsmanager_secret.this[each.key].id
  secret_string  = each.value.value
}
