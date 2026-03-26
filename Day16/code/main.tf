################################################################################
# Day 16 — Secrets Management with AWS Secrets Manager
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws  = { source = "hashicorp/aws",  version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" { region = "us-east-1" }

# ── Create a secret (normally done once, outside Terraform) ────────────────
resource "random_password" "db" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "day16/database/password"
  description             = "RDS master password for Day16 demo"
  recovery_window_in_days = 0   # Immediate deletion for learning (use 7-30 in prod)
  tags = { ManagedBy = "Terraform", Day = "Day16" }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

# ── Read the secret back via data source (how consuming resources use it) ──
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id  = aws_secretsmanager_secret.db_password.id
  depends_on = [aws_secretsmanager_secret_version.db_password]
}

# ── VPC + DB Subnet Group for RDS (required for aws_db_instance) ───────────
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "day16-vpc" }
}

resource "aws_subnet" "a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags              = { Name = "day16-subnet-a" }
}

resource "aws_subnet" "b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags              = { Name = "day16-subnet-b" }
}

resource "aws_db_subnet_group" "main" {
  name       = "day16-db-subnet-group"
  subnet_ids = [aws_subnet.a.id, aws_subnet.b.id]
  tags       = { Name = "day16-db-subnet-group" }
}

resource "aws_security_group" "rds" {
  name        = "day16-rds-sg"
  description = "RDS security group"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "PostgreSQL from VPC only"
  }
  egress {
    from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "day16-rds-sg" }
}

# ── RDS instance using secret from Secrets Manager ────────────────────────
# NOTE: Uncomment in a real account — RDS takes ~10min to create
# resource "aws_db_instance" "main" {
#   identifier             = "day16-postgres"
#   engine                 = "postgres"
#   engine_version         = "15.4"
#   instance_class         = "db.t3.micro"
#   allocated_storage      = 20
#   username               = "dbadmin"
#   password               = data.aws_secretsmanager_secret_version.db_password.secret_string
#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   vpc_security_group_ids = [aws_security_group.rds.id]
#   publicly_accessible    = false
#   skip_final_snapshot    = true
#   deletion_protection    = false
#   tags                   = { Name = "day16-postgres", ManagedBy = "Terraform" }
# }

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_password" {
  description = "Database password (sensitive)"
  value       = data.aws_secretsmanager_secret_version.db_password.secret_string
  sensitive   = true   # Redacted in plan/apply output
}
