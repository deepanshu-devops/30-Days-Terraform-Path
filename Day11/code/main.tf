################################################################################
# Day 11 — Module Versioning: Example caller config
# Shows pinning modules to specific versions
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

# Pinned community module — always use specific version in production
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"  # Pin exact version, never "latest"

  name = "day11-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = false  # Disable for cost in learning
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = { Environment = "learning", Day = "Day11" }
}

output "vpc_id"            { value = module.vpc.vpc_id }
output "private_subnets"   { value = module.vpc.private_subnets }
output "public_subnets"    { value = module.vpc.public_subnets }
