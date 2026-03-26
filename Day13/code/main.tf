################################################################################
# Day 13 — count, for_each & Dynamic Blocks
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

variable "subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    tier              = string
  }))
  default = {
    "public-1a"  = { cidr_block = "10.0.1.0/24",  availability_zone = "us-east-1a", tier = "public"  }
    "public-1b"  = { cidr_block = "10.0.2.0/24",  availability_zone = "us-east-1b", tier = "public"  }
    "private-1a" = { cidr_block = "10.0.11.0/24", availability_zone = "us-east-1a", tier = "private" }
    "private-1b" = { cidr_block = "10.0.12.0/24", availability_zone = "us-east-1b", tier = "private" }
  }
}

variable "sg_ingress_rules" {
  type = list(object({
    from_port = number; to_port = number; protocol = string
    cidr_blocks = list(string); description = string
  }))
  default = [
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTPS" },
    { from_port = 80,  to_port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTP"  }
  ]
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags       = { Name = "day13-vpc", ManagedBy = "Terraform" }
}

# for_each on a map — stable resource addressing
resource "aws_subnet" "main" {
  for_each          = var.subnets
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone
  tags = {
    Name      = "day13-${each.key}"
    Tier      = each.value.tier
    ManagedBy = "Terraform"
  }
}

# Dynamic block for variable ingress rules
resource "aws_security_group" "web" {
  name        = "day13-web-sg"
  description = "Web tier security group"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.sg_ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0; to_port = 0; protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]; description = "All outbound"
  }

  tags = { Name = "day13-web-sg", ManagedBy = "Terraform" }
}

output "subnet_ids"          { value = { for k, v in aws_subnet.main : k => v.id } }
output "public_subnet_ids"   { value = [for k, v in aws_subnet.main : v.id if v.tags["Tier"] == "public"] }
output "private_subnet_ids"  { value = [for k, v in aws_subnet.main : v.id if v.tags["Tier"] == "private"] }
output "security_group_id"   { value = aws_security_group.web.id }
