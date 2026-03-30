################################################################################
# Day 03 — provider.tf
# Topic: Providers, Resources & State
# Real-life: Like choosing which courier service (DHL/FedEx/UPS) to use.
#            AWS provider = Terraform's API client for AWS.
################################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Primary provider — us-east-1
# Real-life: Your main office in New York
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = var.project
      Day       = "Day03"
    }
  }
}

# Aliased provider — eu-west-1
# Real-life: Your branch office in Dublin serving EU customers
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"

  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Project   = var.project
      Day       = "Day03"
      Region    = "eu-west-1"
    }
  }
}
