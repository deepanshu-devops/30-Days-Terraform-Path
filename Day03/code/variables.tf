################################################################################
# Day 03 — variables.tf
# All input variables for this configuration
################################################################################

variable "aws_region" {
  description = "Primary AWS region (e.g. us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name — used in resource names and tags"
  type        = string
  default     = "day03"
}

variable "environment" {
  description = "Deployment environment: dev | staging | prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the US VPC (e.g. 10.0.0.0/16)"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "eu_vpc_cidr" {
  description = "CIDR block for the EU VPC"
  type        = string
  default     = "10.1.0.0/16"
}
