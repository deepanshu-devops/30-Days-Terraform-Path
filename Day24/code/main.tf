################################################################################
# Day24 — main.tf
# Topic: Case Study: 48h to 30min
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
# This config represents the "40-line environment file" from the case study.
# Before: 2 days of manual work. After: this file + terraform apply = 30 minutes.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"
  name = "${local.name_prefix}"
  cidr = var.vpc_cidr
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24","10.0.102.0/24","10.0.103.0/24"]
  enable_nat_gateway   = false
  enable_dns_hostnames = true
  tags = { Environment = var.environment, ManagedBy = "Terraform" }
}
