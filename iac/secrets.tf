# Secrets Manager for API Key
resource "aws_secretsmanager_secret" "api_key" {
  name        = "${local.name_prefix}-api-key"
  description = "API key for authentication"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
  secret_string = jsonencode({
    api_key      = random_password.api_key.result
    valid_groups = var.valid_groups
  })
}
