################################################################################
# Day26 — main.tf
# Topic: Cost Estimation with Infracost
################################################################################

locals { name_prefix = "${var.project}-${var.environment}" }
# Resources below have known monthly costs — run: infracost breakdown --path .
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr   # VPC: FREE
  tags = { Name = "${local.name_prefix}-vpc" }
}
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id; cidr_block = "10.0.1.0/24"; availability_zone = "${var.aws_region}a"
  tags = { Name = "${local.name_prefix}-public" }
}
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id   # IGW: FREE
  tags = { Name = "${local.name_prefix}-igw" }
}
resource "aws_eip" "nat" { domain = "vpc" }  # EIP: ~$3.65/mo if unattached
resource "aws_nat_gateway" "main" {           # NAT: ~$32.40/mo + data transfer
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.main]
  tags = { Name = "${local.name_prefix}-nat" }
}
