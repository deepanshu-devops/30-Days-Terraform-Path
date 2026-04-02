variable "aws_region"  { description = "AWS region"; type = string; default = "us-east-1" }
variable "project"     { description = "Project name"; type = string; default = "day23" }
variable "environment" { description = "dev|staging|prod"; type = string; default = "dev" }
variable "vpc_cidr"    { description = "VPC CIDR block"; type = string; default = "10.0.0.0/16" }

variable "db_username" { description = "RDS master username"; type = string; default = "dbadmin" }
variable "environment" { description = "dev|staging|prod"; type = string; default = "prod" }
