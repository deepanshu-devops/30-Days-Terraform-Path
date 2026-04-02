variable "aws_region"  { description = "AWS region"; type = string; default = "us-east-1" }
variable "project"     { description = "Project name"; type = string; default = "day13" }
variable "environment" { description = "dev|staging|prod"; type = string; default = "dev" }
variable "vpc_cidr"    { description = "VPC CIDR block"; type = string; default = "10.0.0.0/16" }

variable "subnets" {
  description = "Map of subnet name -> CIDR and AZ"
  type = map(object({ cidr = string; az = string; tier = string }))
  default = {
    "public-1a"  = { cidr = "10.0.1.0/24",  az = "us-east-1a", tier = "public"  }
    "public-1b"  = { cidr = "10.0.2.0/24",  az = "us-east-1b", tier = "public"  }
    "private-1a" = { cidr = "10.0.11.0/24", az = "us-east-1a", tier = "private" }
    "private-1b" = { cidr = "10.0.12.0/24", az = "us-east-1b", tier = "private" }
  }
}
variable "ingress_rules" {
  description = "Ingress rules for the web security group"
  type = list(object({ port = number; protocol = string; cidr = string; description = string }))
  default = [
    { port = 443; protocol = "tcp"; cidr = "0.0.0.0/0"; description = "HTTPS" }
    { port = 80;  protocol = "tcp"; cidr = "0.0.0.0/0"; description = "HTTP redirect" }
  ]
}
