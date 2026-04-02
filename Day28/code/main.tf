################################################################################
# Day28 — main.tf
# Topic: Interview Questions
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
# Demonstrates concepts covered in the interview questions:
# - for_each (stable keys), data sources, outputs, lifecycle, sensitive vars
variable "env_subnets" {
  type = map(object({ cidr = string; az = string }))
  default = { "public-a" = { cidr = "10.0.1.0/24"; az = "us-east-1a" } }
}
data "aws_caller_identity" "current" {}
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = { Name = "${local.name_prefix}-vpc", ManagedBy = "Terraform" }
}
resource "aws_subnet" "main" {
  for_each          = var.env_subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags              = { Name = "${local.name_prefix}-${each.key}" }
}
