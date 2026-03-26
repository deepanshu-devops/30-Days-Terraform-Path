################################################################################
# Day 05 — Variables, Outputs & Locals
################################################################################

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used in resource naming"
  type        = string
  default     = "day05"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create a NAT Gateway (costs money)"
  type        = bool
  default     = false
}

variable "subnet_count" {
  description = "Number of subnets to create"
  type        = number
  default     = 2
  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 6
    error_message = "Subnet count must be between 1 and 6."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  name_prefix = "${var.project}-${var.environment}"

  # Environment-specific settings using conditional
  instance_type = var.environment == "production" ? "t3.medium" : "t3.micro"
  multi_az      = var.environment == "production"

  # Common tags merged with user-provided tags
  common_tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "Terraform"
      Region      = var.aws_region
    },
    var.tags
  )

  # Compute subnet CIDRs from the VPC CIDR
  subnet_cidrs = [for i in range(var.subnet_count) : cidrsubnet(var.vpc_cidr, 8, i + 1)]
}

# ---------------------------------------------------------------------------
# Data Sources
# ---------------------------------------------------------------------------
data "aws_availability_zones" "available" { state = "available" }

# ---------------------------------------------------------------------------
# Resources
# ---------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.common_tags, { Name = "${local.name_prefix}-vpc" })
}

resource "aws_subnet" "public" {
  count             = var.subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-subnet-${count.index + 1}"
    Tier = "public"
  })
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "vpc_id" {
  description = "The VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_arn" {
  description = "The VPC ARN"
  value       = aws_vpc.main.arn
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = aws_subnet.public[*].id
}

output "subnet_cidr_blocks" {
  description = "CIDR blocks of created subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "name_prefix" {
  description = "The computed name prefix used for all resources"
  value       = local.name_prefix
}

output "environment_config" {
  description = "Environment-specific computed configuration"
  value = {
    instance_type      = local.instance_type
    multi_az_enabled   = local.multi_az
    nat_gateway_enabled = var.enable_nat_gateway
  }
}
