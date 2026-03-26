################################################################################
# Day 23 — Production RDS Multi-AZ
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" { region = var.aws_region }

variable "aws_region"  { type = string; default = "us-east-1" }
variable "project"     { type = string; default = "myapp" }
variable "environment" { type = string; default = "prod" }
variable "db_username" { type = string; default = "dbadmin" }

locals {
  name        = "${var.project}-${var.environment}"
  common_tags = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" }
}

resource "random_password" "db" {
  length = 32; special = true; override_special = "!#$%&*()-_=+[]<>:"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${local.name}/rds/password"
  recovery_window_in_days = 7
  tags                    = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true; enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 8, count.index + 10)
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"
  tags = merge(local.common_tags, { Name = "${local.name}-private-${count.index + 1}", Tier = "private" })
}

resource "aws_db_subnet_group" "main" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags       = merge(local.common_tags, { Name = "${local.name}-db-subnet-group" })
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "RDS — only allow from application tier"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port   = 5432; to_port = 5432; protocol = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
    description = "PostgreSQL from VPC only"
  }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  tags = merge(local.common_tags, { Name = "${local.name}-rds-sg" })
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.common_tags
}

# NOTE: RDS creation takes ~10 minutes and costs money. Comment out for learning.
# resource "aws_db_instance" "main" {
#   identifier             = local.name
#   engine                 = "postgres"
#   engine_version         = "15.4"
#   instance_class         = "db.t3.micro"   # Use db.r6g.large in production
#   allocated_storage      = 20
#   max_allocated_storage  = 100
#   storage_encrypted      = true
#   kms_key_id             = aws_kms_key.rds.arn
#   multi_az               = true
#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   vpc_security_group_ids = [aws_security_group.rds.id]
#   publicly_accessible    = false
#   username               = var.db_username
#   password               = aws_secretsmanager_secret_version.db_password.secret_string
#   backup_retention_period   = 7
#   backup_window             = "03:00-04:00"
#   maintenance_window        = "Mon:04:00-Mon:05:00"
#   deletion_protection       = true
#   skip_final_snapshot       = false
#   final_snapshot_identifier = "${local.name}-final"
#   performance_insights_enabled = true
#   tags                      = merge(local.common_tags, { Name = local.name })
# }

output "db_secret_arn"     { value = aws_secretsmanager_secret.db_password.arn }
output "db_subnet_group"   { value = aws_db_subnet_group.main.name }
output "rds_security_group" { value = aws_security_group.rds.id }
