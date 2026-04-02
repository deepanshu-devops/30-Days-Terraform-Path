output "db_subnet_group"     { description = "DB subnet group name"; value = aws_db_subnet_group.main.name }
output "rds_security_group"  { description = "RDS security group ID"; value = aws_security_group.rds.id }
output "kms_key_arn"         { description = "KMS key ARN for RDS encryption"; value = aws_kms_key.rds.arn }
output "secret_arn"          { description = "Secrets Manager ARN for DB password"; value = aws_secretsmanager_secret.db_password.arn }
