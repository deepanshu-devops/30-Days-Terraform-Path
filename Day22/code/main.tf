################################################################################
# Day22 — main.tf
# Topic: Provisioning EKS End-to-End
# Real-life: EKS: Without Terraform, setting up an EKS cluster takes 45 minutes in the console — and the next cluster will have different settings because you forgot a checkbox. With Terraform: both clusters are identical, provisioned in 10 minutes, version-controlled, reviewable.
################################################################################

locals {
  cluster_name = "${var.project}-${var.environment}"
  common_tags  = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform" }
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.5.3"
  name = "${local.cluster_name}-vpc"
  cidr = var.vpc_cidr
  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24","10.0.102.0/24","10.0.103.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true   # Set false in prod for HA
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
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"
  cluster_name    = local.cluster_name
  cluster_version = "1.29"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false  # Never expose Kubernetes API publicly
  enable_irsa                     = true
  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }
  eks_managed_node_groups = {
    general = {
      instance_types = ["t3.medium"]
      min_size = 1; max_size = 5; desired_size = 2
      disk_size = 50
    }
  }
  enable_cluster_creator_admin_permissions = true
  tags = local.common_tags
}
