# SECRET FOR RDS
resource "aws_secretsmanager_secret" "secret" {
  name = local.tags.Service

  recovery_window_in_days = 0

	tags = merge(
		{ Resource = "secret" },
		local.tags
	)
}

locals {
  db_secret = {
    url = "jdbc:postgresql://rds.${local.domain}:5432/${local.tags.Service}"
    username = "${local.tags.Service}_dba"
    password = "${var.db_password}"
    port = 5432
    simple_url = "rds.${local.domain}"
  }
}

resource "aws_secretsmanager_secret_version" "secret_version" {
  secret_id     = aws_secretsmanager_secret.secret.id
  secret_string = jsonencode(local.db_secret)
}