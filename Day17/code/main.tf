################################################################################
# Day17 — main.tf
# Topic: IAM Least Privilege
# Real-life: IAM: A Terraform role with AdministratorAccess is compromised. Attacker has full AWS access. With least-privilege: even if the role is compromised, attacker can only create VPCs — not create IAM users, not read S3, not touch anything else.
################################################################################

data "aws_caller_identity" "current" {}
variable "github_org"  { type = string; default = "myorg" }
variable "github_repo" { type = string; default = "infrastructure" }
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
resource "aws_iam_role" "terraform_ci" {
  name = "TerraformCIRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike   = { "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*" }
      }
    }]
  })
  tags = { Name = "TerraformCIRole" }
}
resource "aws_iam_policy" "terraform_vpc" {
  name        = "TerraformVPCPolicy"
  description = "Minimum permissions Terraform needs to manage VPC resources"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ec2:CreateVpc","ec2:DeleteVpc","ec2:DescribeVpcs","ec2:ModifyVpcAttribute","ec2:CreateSubnet","ec2:DeleteSubnet","ec2:DescribeSubnets","ec2:CreateInternetGateway","ec2:DeleteInternetGateway","ec2:AttachInternetGateway","ec2:DetachInternetGateway","ec2:DescribeInternetGateways","ec2:CreateRouteTable","ec2:DeleteRouteTable","ec2:AssociateRouteTable","ec2:DisassociateRouteTable","ec2:CreateRoute","ec2:DeleteRoute","ec2:DescribeRouteTables","ec2:CreateTags","ec2:DeleteTags","ec2:DescribeAvailabilityZones"]
      Resource = "*"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "terraform_vpc" {
  role       = aws_iam_role.terraform_ci.name
  policy_arn = aws_iam_policy.terraform_vpc.arn
}
