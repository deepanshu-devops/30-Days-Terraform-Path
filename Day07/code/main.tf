################################################################################
# Day 07 — Functions & Expressions Demo
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

variable "project"     { type = string; default = "day07" }
variable "environment" { type = string; default = "dev" }
variable "vpc_cidr"    { type = string; default = "10.0.0.0/16" }
variable "subnet_count" { type = number; default = 3 }
variable "env_list"    { type = list(string); default = ["dev", "staging", "production"] }

locals {
  # String manipulation
  name_prefix  = lower(replace("${var.project}-${var.environment}", "_", "-"))
  project_upper = upper(var.project)

  # Network calculation using functions
  subnet_cidrs = [for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]

  # Conditional
  is_production   = var.environment == "production"
  instance_type   = local.is_production ? "t3.large" : "t3.micro"
  min_az_count    = local.is_production ? 3 : 2

  # Collection transformations
  uppercase_envs  = [for e in var.env_list : upper(e)]
  env_map         = {for idx, e in var.env_list : e => idx}
  non_dev_envs    = [for e in var.env_list : e if e != "dev"]

  # Common tags using merge
  common_tags = merge(
    { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" },
    local.is_production ? { CriticalLevel = "high", Backup = "required" } : {}
  )
}

data "aws_availability_zones" "available" { state = "available" }

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "main" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags              = merge(local.common_tags, { Name = "${local.name_prefix}-subnet-${count.index + 1}" })
}

output "computed_name_prefix" { value = local.name_prefix }
output "subnet_cidrs"         { value = local.subnet_cidrs }
output "uppercase_environments" { value = local.uppercase_envs }
output "env_index_map"         { value = local.env_map }
output "non_dev_environments"  { value = local.non_dev_envs }
output "instance_type"         { value = local.instance_type }
output "common_tags"           { value = local.common_tags }
