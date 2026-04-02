################################################################################
# Day 23 — main.tf
# Topic: RDS Multi-AZ with Automatic Failover
# Real-life: Single-AZ RDS went down for 4 hours during an AZ outage.
#            Multi-AZ = automatic failover in 60s, no manual intervention.
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }

resource "random_password" "db" {
  length = 32; special = true; override_special = "!#$%&*()-_=+[]<>:"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name_prefix}/rds/master-password"
  recovery_window_in_days = 0
  tags                    = { Name = "${local.name_prefix}-db-secret" }
}
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr; enable_dns_support = true; enable_dns_hostnames = true
  tags       = { Name = "${local.name_prefix}-vpc" }
}
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  tags              = { Name = "${local.name_prefix}-private-${count.index + 1}", Tier = "private" }
}
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = { Name = "${local.name_prefix}-db-subnet-group" }
}
resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "RDS — only allow connections from application tier"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 5432; to_port = 5432; protocol = "tcp"
    cidr_blocks = [var.vpc_cidr]; description = "PostgreSQL from VPC only"
  }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "${local.name_prefix}-rds-sg" }
}
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption at rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = { Name = "${local.name_prefix}-rds-kms" }
}

# ── RDS Multi-AZ Instance ─────────────────────────────────────────────────────
# NOTE: Creates a billable RDS instance (~$25/month for db.t3.micro)
# Uncomment when ready to test. Remember to run terraform destroy after.
# resource "aws_db_instance" "main" {
#   identifier             = local.name_prefix
#   engine                 = "postgres"
#   engine_version         = "15.4"
#   instance_class         = "db.t3.micro"       # Use db.r6g.large in production
#   allocated_storage      = 20
#   max_allocated_storage  = 100                 # Autoscaling up to 100 GB
#   storage_encrypted      = true
#   kms_key_id             = aws_kms_key.rds.arn
#   multi_az               = true                # Standby in a different AZ
#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   vpc_security_group_ids = [aws_security_group.rds.id]
#   publicly_accessible    = false               # NEVER true in production
#   username               = var.db_username
#   password               = aws_secretsmanager_secret_version.db_password.secret_string
#   backup_retention_period   = 7               # Keep 7 days of automated backups
#   backup_window             = "03:00-04:00"   # 3am UTC — low-traffic window
#   maintenance_window        = "Mon:04:00-Mon:05:00"
#   deletion_protection       = true             # Prevent accidental destroy
#   skip_final_snapshot       = false
#   final_snapshot_identifier = "${local.name_prefix}-final-snapshot"
#   performance_insights_enabled = true
#   tags = { Name = local.name_prefix, MultiAZ = "true" }
# }
