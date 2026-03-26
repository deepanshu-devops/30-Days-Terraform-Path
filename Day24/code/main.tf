################################################################################
# Day 24 — Production Environment from Module Library
# Shows how 40 lines can provision a full environment
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket = "my-org-terraform-state"
    key    = "environments/prod/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt = true
  }
}

provider "aws" { region = "us-east-1" }

variable "project"     { type = string }
variable "environment" { type = string }

# ── Use community modules as stand-ins for internal module library ────────

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"

  name = "${var.project}-${var.environment}"
  cidr = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = false
  enable_dns_hostnames = true
  tags = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" }
}

output "vpc_id"           { value = module.vpc.vpc_id }
output "private_subnets"  { value = module.vpc.private_subnets }
output "public_subnets"   { value = module.vpc.public_subnets }
