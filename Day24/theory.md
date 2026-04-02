# Day 24 — Case Study: 48 Hours to 30 Minutes

## Real-Life Example 🏗️ (This IS the real-life example)

This is a real story from Amdocs. Not a hypothetical.

**The problem:** When I joined the Bell Canada project, provisioning a new environment took 48 hours. Two senior engineers spent a full day clicking through the AWS Console, following a Confluence doc that was 6 months out of date, debugging one-off misconfigurations, and arguing about whether a security group rule should allow 443 or 8443.

The result was never reproducible. Each environment had slight differences. Debugging cross-environment issues was a nightmare.

---

## Root Causes of the 48-Hour Problem

| Problem | Cause |
|---------|-------|
| "It worked on my environment" | No code — every environment built differently |
| Expert dependency | Only 2-3 engineers knew the full setup |
| Outdated docs | Confluence doc was 6 months behind reality |
| No audit trail | Who added this security group rule and why? |
| Hard to reproduce | Click-through setup = human variation every time |
| Slow onboarding | New engineers needed weeks to understand the infra |

---

## The Solution: Module Library

**Phase 1 (Month 1):** Audit all existing infrastructure. Map every resource type.

```
VPC, Subnets, Route Tables, NAT Gateways
Security Groups (15 different patterns)
EKS Cluster + Node Groups
RDS Multi-AZ + Parameter Groups
ALB + Target Groups + Listeners + WAF
IAM Roles (Terraform execution, EKS node, application)
Route53 Zones + Records
S3 Buckets (logs, artifacts, state)
MSK (Kafka)
SNS + SQS
```

**Phase 2 (Month 2):** Build the module library.

```
terraform-modules/ (private GitHub repo, versioned)
├── vpc/         v1.0 → v2.1   (20 PRs, evolved over 3 months)
├── eks/         v1.0 → v1.4
├── rds/         v1.0 → v1.2
├── alb/         v1.0
├── iam/         v1.0 → v1.1
├── route53/     v1.0
└── monitoring/  v1.0
```

**Phase 3 (Month 3):** The 40-line environment file.

```hcl
# environments/prod/main.tf — this is the entire environment definition
module "vpc" {
  source = "git::https://github.com/amdocs-org/terraform-modules.git//vpc?ref=v2.1.0"
  name   = "bell-canada-prod"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "eks" {
  source       = "git::https://...//eks?ref=v1.4.0"
  cluster_name = "bell-canada-prod"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids
}

module "rds" {
  source     = "git::https://...//rds?ref=v1.2.0"
  identifier = "bell-canada-prod"
  subnet_ids = module.vpc.private_subnet_ids
}
```

`terraform apply`. Coffee break. Return to a fully provisioned environment.

---

## The Results

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| New environment provisioning | 48 hours | 30 minutes | **96× faster** |
| New project onboarding | 3 days | < 1 hour | **24× faster** |
| Engineers who can provision | 2-3 seniors | Any team member | **Democratised** |
| Manual errors per deploy | Multiple | ~Zero | **Eliminated** |
| Environments created per quarter | 2-3 | 20+ | **10× more** |
| Time to reproduce a bug environment | 2+ days | 30 minutes | **96× faster** |

---

## The Deeper Lesson

The time savings were the visible win. The invisible win was more important:

**Knowledge was encoded into code.**

Before modules, if the two senior engineers who "knew the setup" left, the team would be starting from scratch. The knowledge lived in their heads.

After modules, the knowledge lives in Git. It's versioned. It's reviewable. It's testable. Any engineer can read a module and understand exactly what it does and why.

Infrastructure as Code is not about saving time. It's about building institutional knowledge that outlasts any individual.

---

## How to Apply This at Your Company

```bash
# Week 1: Audit
aws ec2 describe-vpcs
aws ec2 describe-subnets
aws rds describe-db-instances
# Map every resource type you use

# Week 2: Write your first module
# Start with what you use most (usually VPC)
# Build it, test it, document it, tag v1.0.0

# Week 3: Migrate one project to use the module
# The first migration reveals all the gaps

# Month 2: Add 2-3 more modules
# Week 8: Measure provisioning time
# Week 12: Measure again

# You will see 90%+ reduction in provisioning time.
```
