variable "aws_region"  { description = "AWS region"; type = string; default = "us-east-1" }
variable "project"     { description = "Project name"; type = string; default = "day14" }
variable "environment" { description = "dev|staging|prod"; type = string; default = "dev" }
variable "vpc_cidr"    { description = "VPC CIDR block"; type = string; default = "10.0.0.0/16" }

variable "existing_vpc_id" {
  description = "ID of an existing VPC to import (fill in from AWS Console)"
  type        = string
  default     = "vpc-xxxxxxxxxxxxxxxxx"
}
