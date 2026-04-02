################################################################################
# Day 09 — main.tf
# Topic: State Corruption — Causes & Prevention
#
# Real-life scenario:
#   Production state got corrupted. Resources were shown as needing recreation.
#   Two RDS instances, EKS cluster. Run apply and they'd all be destroyed.
#   This config demonstrates safe state management patterns.
################################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_subnet" "primary" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  tags              = { Name = "${local.name_prefix}-primary-subnet" }
}

# ── S3 with delete protection — demonstrates prevent_destroy ─────────────────
resource "aws_s3_bucket" "critical_data" {
  bucket        = "${local.name_prefix}-critical-data"
  force_destroy = false   # In prod: never set force_destroy = true

  lifecycle {
    prevent_destroy = true  # Terraform will refuse to destroy this resource
  }

  tags = { Name = "${local.name_prefix}-critical-data", CriticalLevel = "high" }
}

resource "aws_s3_bucket_versioning" "critical_data" {
  bucket = aws_s3_bucket.critical_data.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "critical_data" {
  bucket = aws_s3_bucket.critical_data.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" }
  }
}
