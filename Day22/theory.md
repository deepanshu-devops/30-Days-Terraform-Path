# Day 22 — Provisioning EKS End-to-End with Terraform

## WHAT
A production EKS cluster requires: VPC, subnets, EKS control plane, managed node groups, OIDC provider, IRSA (IAM Roles for Service Accounts), and core add-ons.

## Architecture

```
VPC (10.0.0.0/16)
  ├── Public Subnets  (NAT Gateways, Load Balancers)
  └── Private Subnets (EKS Nodes — NEVER public)
        └── EKS Cluster
              ├── Control Plane (AWS-managed, private endpoint)
              ├── Node Group: general (m5.large × 2-10)
              ├── Node Group: memory (r6i.large × 1-5)
              └── Add-ons: CoreDNS, kube-proxy, VPC CNI, EBS CSI
```

## Complete EKS Configuration

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.project}-${var.environment}"
  cluster_version = "1.29"

  # Network
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Security — private endpoint only
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false

  # Enable IRSA
  enable_irsa = true

  # Managed Add-ons (version-pinned)
  cluster_addons = {
    coredns = {
      most_recent = true
      configuration_values = jsonencode({
        replicaCount = 2
        resources = { requests = { cpu = "100m", memory = "128Mi" } }
      })
    }
    kube-proxy    = { most_recent = true }
    vpc-cni       = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }

  # Node Groups
  eks_managed_node_groups = {
    general = {
      name           = "general"
      instance_types = ["m5.large"]
      min_size       = 2
      max_size       = 10
      desired_size   = 3
      disk_size      = 50

      labels = { role = "general" }
      taints = {}

      update_config = { max_unavailable_percentage = 25 }
    }
    memory = {
      name           = "memory-optimized"
      instance_types = ["r6i.large"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
      disk_size      = 100

      labels = { role = "memory-intensive" }
      taints = [{ key = "memory-intensive", value = "true", effect = "NO_SCHEDULE" }]
    }
  }

  # Access
  enable_cluster_creator_admin_permissions = true

  tags = local.common_tags
}
```

## Post-Cluster: Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name my-cluster

kubectl get nodes
kubectl get pods -A
```

## IRSA — IAM Roles for Service Accounts

```hcl
module "load_balancer_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
```

---

## Audience Levels

### 🟢 Beginner
EKS = managed Kubernetes. Terraform provisions the entire cluster so you never click in the console. The module (`terraform-aws-modules/eks/aws`) handles 90% of the complexity.

### 🔵 Intermediate
Always use private endpoint (`cluster_endpoint_public_access = false`). Access the API server via VPN or bastion host. Never expose the Kubernetes API to the internet.

### 🟠 Advanced
Node group sizing: start with m5.large × 3 for general workloads. Monitor with CloudWatch Container Insights. Enable Cluster Autoscaler (IRSA role + Helm chart). Add Karpenter for more flexible node provisioning.

### 🔴 Expert
At 200K+ concurrent sessions: use multiple node groups with different instance types, Spot instances for cost (with on-demand fallback), topology spread constraints for cross-AZ distribution, PodDisruptionBudgets for zero-downtime node drain.
