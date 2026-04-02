################################################################################
# Day16 — main.tf
# Topic: Secrets Management
# Real-life: Secrets: A developer accidentally commits a DB password to Git. It sits in history for 6 months. Even after deletion, it's retrievable. The fix: never put secrets in code — fetch them from Secrets Manager at apply time.
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
resource "random_password" "db" {
  length = 32; special = true; override_special = "!#$%&*()-_=+[]<>:"
}
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}/rds/password"
  description             = "RDS master password — managed by Terraform"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name_prefix}-db-secret" }
}
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id  = aws_secretsmanager_secret.db_password.id
  depends_on = [aws_secretsmanager_secret_version.db_password]
}
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = { Name = "${local.name_prefix}-vpc" }
}
