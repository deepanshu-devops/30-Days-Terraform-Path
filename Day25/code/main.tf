################################################################################
# Day 25 — Drift Detection Setup
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" { region = "us-east-1" }

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "day25-drift-demo", ManagedBy = "Terraform" }
}

resource "aws_security_group" "web" {
  name   = "day25-web-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 443; to_port = 443; protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "day25-web-sg", ManagedBy = "Terraform" }
}

# SNS topic for drift alerts
resource "aws_sns_topic" "drift_alerts" {
  name = "day25-terraform-drift-alerts"
  tags = { Name = "drift-alerts", ManagedBy = "Terraform" }
}

output "vpc_id"           { value = aws_vpc.main.id }
output "security_group_id" { value = aws_security_group.web.id }
output "alert_topic_arn"  { value = aws_sns_topic.drift_alerts.arn }

# After apply:
# 1. Go to AWS Console -> VPC -> add a tag manually: manual=test
# 2. Run: terraform plan
# 3. You will see: ~ update aws_vpc.main (drift detected!)
# 4. Run: terraform apply -auto-approve (fixes drift)
