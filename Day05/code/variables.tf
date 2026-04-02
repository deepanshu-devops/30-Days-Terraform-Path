################################################################################
# Day 05 — variables.tf
# Demonstrates: all variable types, validation, sensitive flag
################################################################################

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — appears in every resource name"
  type        = string
  default     = "day05"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Must be a valid CIDR block like 10.0.0.0/16."
  }
}

variable "subnet_count" {
  description = "Number of public subnets to create (1–4)"
  type        = number
  default     = 2
  validation {
    condition     = var.subnet_count >= 1 && var.subnet_count <= 4
    error_message = "subnet_count must be between 1 and 4."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway for private subnet internet access (costs ~$32/month)"
  type        = bool
  default     = false
}

variable "owner_email" {
  description = "Email of the team that owns this infrastructure"
  type        = string
  default     = "platform-team@company.com"
}

variable "additional_tags" {
  description = "Extra tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Sensitive: value is hidden in plan output and logs
variable "db_password" {
  description = "Database master password (never commit the real value)"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}
