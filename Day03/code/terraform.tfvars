# Day 03 — terraform.tfvars
# Override defaults here. Never commit real secrets.

aws_region  = "us-east-1"
project     = "day03"
environment = "dev"
vpc_cidr    = "10.0.0.0/16"
eu_vpc_cidr = "10.1.0.0/16"
