################################################################################
# Day 14 — main.tf
# Topic: Terraform Import & Migrating Existing Infrastructure
#
# Real-life scenario:
#   You joined a company that has been building infra manually in the console
#   for 2 years. VPCs, EC2s, RDS — all unmanaged. Your job: bring it all
#   under Terraform without destroying and recreating anything.
#
# HOW TO USE THIS FILE:
# 1. Look up your existing resource IDs in the AWS Console
# 2. Replace the placeholder IDs in the import blocks below
# 3. Run: terraform plan -generate-config-out=generated.tf
# 4. Review generated.tf, clean it up, paste into main.tf
# 5. Run: terraform plan (should show "No changes" when config matches reality)
################################################################################

# ── NEW WAY: Import Blocks (Terraform >= 1.5) — RECOMMENDED ─────────────────
# Declarative — the import is part of your code, visible in Git history

# Step 1: Add import block with your real resource ID
# Step 2: Run: terraform plan -generate-config-out=generated.tf
# Step 3: Terraform generates the resource block for you

# Uncomment and replace with your real VPC ID:
# import {
#   id = "vpc-0abc123456789"   # From: AWS Console → VPC → VPC ID
#   to = aws_vpc.imported
# }

# After running plan -generate-config-out=generated.tf, Terraform writes:
# resource "aws_vpc" "imported" {
#   cidr_block = "10.0.0.0/16"
#   ... (all attributes matching the real VPC)
# }

# ── For learning: create a VPC we can then import ────────────────────────────
resource "aws_vpc" "demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project}-import-demo" }
}

# After apply:
# 1. Remove the resource block above (aws_vpc.demo)
# 2. Add: import { id = "<vpc-id from output>"; to = aws_vpc.demo }
# 3. Add the resource block back
# 4. Run: terraform plan  → should show "No changes"
# This simulates importing an existing resource
