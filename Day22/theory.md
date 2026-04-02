# Day 22 — Provisioning EKS End-to-End with Terraform

## Real-Life Example 🏗️

**The Manual EKS Setup:**  
Setting up EKS in the console for the first time: 45 minutes, 30+ configuration decisions. OIDC setup, security groups, IAM roles, node group parameters, add-on versions.

Setting up the second EKS cluster: 40 minutes — you remember most of it.  
The third: 35 minutes — but it has slightly different node sizing than the second because you forgot.

Three clusters, three slightly different configurations. When a CVE requires updating kube-proxy on all three, you update each one differently.

**With Terraform:**  
All three clusters are defined in code. Same module, different inputs. Update the module → all three clusters get identical updates. Provisioning time: 10 minutes per cluster.

At Amdocs: we provision EKS clusters that handle 200K+ concurrent sessions. All via this pattern.

---

## What a Production EKS Cluster Requires

```
VPC
├── Public Subnets  (NAT Gateways, Load Balancers, Bastion)
└── Private Subnets (EKS Nodes — NEVER in public subnets)
       └── EKS Cluster
             ├── Control Plane (AWS-managed, private API endpoint only)
             ├── OIDC Provider (enables IRSA)
             ├── Node Groups
             │   ├── general   (m5.large × 2-10, for most workloads)
             │   └── memory    (r6i.large × 1-5, for DB-heavy apps)
             └── Add-ons (version-pinned)
                 ├── CoreDNS
                 ├── kube-proxy
                 ├── VPC CNI
                 └── EBS CSI Driver
```

---

## IRSA — IAM Roles for Service Accounts

The most important EKS security concept Terraform engineers must understand.

**Without IRSA:** All pods on a node share the node's IAM instance profile. If any pod is compromised, the attacker gets the full node IAM role.

**With IRSA:** Each pod gets its own IAM role, scoped to only what that service needs. A compromised pod can only access its own permissions.

```hcl
# Enable IRSA on the cluster
module "eks" {
  enable_irsa = true    # Creates an OIDC provider
}

# Create a role for a specific application
module "my_app_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "my-app-s3-readonly"
  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:my-app"]    # namespace:serviceaccount
    }
  }
}

# Now `my-app` pod gets its own IAM role.
# Other pods on the same node get nothing from this role.
```

---

## Security: Private Endpoint Only

```hcl
module "eks" {
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = false   # NEVER expose Kubernetes API to internet

  # To access the cluster from your machine:
  # 1. VPN into the VPC, or
  # 2. Use a bastion host, or
  # 3. Use AWS Cloud9/SSM
}
```

A public Kubernetes API endpoint is reachable by anyone on the internet. Even with authentication, it's an attack surface. Private-only = only traffic from inside the VPC can reach it.

---

## Node Group Best Practices

```hcl
eks_managed_node_groups = {
  general = {
    instance_types = ["m5.large"]
    min_size       = 2      # Never less than 2 — one per AZ minimum
    max_size       = 10     # Cluster autoscaler ceiling
    desired_size   = 3      # Starting point

    disk_size = 50          # 50 GB per node

    update_config = {
      max_unavailable_percentage = 25    # Only 25% of nodes update at once
    }

    labels = { role = "general" }
    taints = []    # no taints for general workloads
  }

  memory_optimized = {
    instance_types = ["r6i.large"]
    min_size       = 0      # Scale to zero when not needed
    max_size       = 5
    desired_size   = 0

    taints = [{
      key    = "workload-type"
      value  = "memory-intensive"
      effect = "NO_SCHEDULE"    # Only pods that tolerate this taint run here
    }]
  }
}
```

---

## After Apply: Configure kubectl

```bash
# The output "configure_kubectl" contains this command:
aws eks update-kubeconfig   --region us-east-1   --name myapp-prod

# Verify
kubectl get nodes
kubectl get pods -A

# Check cluster version
kubectl version
```
