################################################################################
# Day25 — main.tf
# Topic: Drift Detection
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr; enable_dns_support = true; enable_dns_hostnames = true
  tags = { Name = "${local.name_prefix}-vpc", ManagedBy = "Terraform" }
}
resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "Web tier — managed by Terraform. Manual changes will be reverted."
  vpc_id      = aws_vpc.main.id
  ingress { from_port = 443; to_port = 443; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTPS" }
  egress  { from_port = 0;   to_port = 0;   protocol = "-1";  cidr_blocks = ["0.0.0.0/0"]; description = "All out" }
  tags = { Name = "${local.name_prefix}-web-sg", ManagedBy = "Terraform" }
}
resource "aws_sns_topic" "drift_alerts" {
  name = "${local.name_prefix}-drift-alerts"
  tags = { Name = "drift-alerts" }
}
