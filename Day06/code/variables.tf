variable "aws_region"  { description = "AWS region"; type = string; default = "us-east-1" }
variable "project"     { description = "Project name"; type = string; default = "day06" }
variable "environment" { description = "Environment: dev|staging|prod"; type = string; default = "dev" }
variable "vpc_cidr"    { description = "VPC CIDR"; type = string; default = "10.0.0.0/16" }
