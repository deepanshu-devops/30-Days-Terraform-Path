################################################################################
# Day 08 — provider.tf  (BOOTSTRAP config — run this ONCE)
# Topic: Remote State with S3 + DynamoDB Locking
# NOTE: This file uses LOCAL state intentionally.
#       After apply, migrate every other project to use this S3 backend.
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # NO backend block here — bootstrap uses local state
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = { ManagedBy = "Terraform", Project = var.project, Day = "Day08", Purpose = "state-backend" }
  }
}
