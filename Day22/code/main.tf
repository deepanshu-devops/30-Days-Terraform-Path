################################################################################
# Day 22 — Production EKS with Terraform
################################################################################
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws        = { source = "hashicorp/aws",        version = "~> 5.0" }
    kubernetes = { source = "hashicorp/kubernetes",  version = "~> 2.0" }
    helm       = { source = "hashicorp/helm",        version = "~> 2.0" }
  }
}

provider "aws" { region = var.aws_region }

variable "aws_region"  { type = string; default = "us-east-1" }
variable "project"     { type = string; default = "myapp" }
variable "environment" { type = string; default = "prod" }

locals {
  cluster_name = "${var.project}-${var.environment}"
  common_tags  = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" }
}

# ── VPC ────────────────────────────────────────────────────────────────────
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  intra_subnets   = ["10.0.51.0/24",  "10.0.52.0/24",  "10.0.53.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false  # One per AZ for HA
  enable_dns_hostnames = true

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  tags = local.common_tags
}

# ── EKS Cluster ───────────────────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = "1.29"

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false
  enable_irsa                     = true

  cluster_addons = {
    coredns             = { most_recent = true }
    kube-proxy          = { most_recent = true }
    vpc-cni             = { most_recent = true }
    aws-ebs-csi-driver  = { most_recent = true }
  }

  eks_managed_node_groups = {
    general = {
      instance_types = ["m5.large"]
      min_size = 2; max_size = 10; desired_size = 3
      disk_size = 50
      update_config = { max_unavailable_percentage = 25 }
      labels = { role = "general" }
    }
  }

  enable_cluster_creator_admin_permissions = true
  tags = local.common_tags
}

output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
