output "secret_arn" { description = "Secret ARN"; value = aws_secretsmanager_secret.db_password.arn }
output "db_password" { description = "DB password (sensitive)"; value = data.aws_secretsmanager_secret_version.db_password.secret_string; sensitive = true }
output "vpc_id" { description = "VPC ID"; value = aws_vpc.main.id }
