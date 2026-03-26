# Day 24 — How We Cut Provisioning from 48 Hours to 30 Minutes

## The Problem
Every new environment required 48 hours of manual work: clicking through the AWS Console, following outdated Confluence docs, debugging one-off misconfigurations.

## What We Built

### The Module Library
```
terraform-modules/
  vpc/          v2.1.0  — VPC + subnets + NAT + route tables
  eks/          v1.4.0  — EKS cluster + node groups + IRSA
  rds/          v1.2.0  — RDS multi-AZ + KMS + Secrets Manager
  alb/          v1.0.0  — ALB + target groups + listeners + WAF
  iam/          v1.1.0  — Standard roles + policies
  route53/      v1.0.0  — Zone delegation + records
  monitoring/   v1.0.0  — CloudWatch dashboards + alarms + SNS
```

### The Environment Config (40 lines)
```hcl
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v2.1.0"
  name   = "myapp-prod"
  cidr   = "10.0.0.0/16"
  azs    = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

module "eks" {
  source         = "git::https://github.com/org/terraform-modules.git//eks?ref=v1.4.0"
  cluster_name   = "myapp-prod"
  vpc_id         = module.vpc.vpc_id
  subnet_ids     = module.vpc.private_subnet_ids
}

module "rds" {
  source         = "git::https://github.com/org/terraform-modules.git//rds?ref=v1.2.0"
  identifier     = "myapp-prod"
  subnet_ids     = module.vpc.private_subnet_ids
  vpc_id         = module.vpc.vpc_id
}
```

### Results
| Metric | Before | After |
|---|---|---|
| Provisioning time | 48 hours | 30 minutes |
| New project onboarding | 3 days | < 1 hour |
| Manual errors per deploy | Multiple | ~Zero |
| Knowledge dependency | 3 senior engineers | Any team member |
| Environments created per quarter | 2-3 | 20+ |

## Key Lessons
1. **Modules as products** — treated with versioning, docs, and changelogs
2. **Opinionated defaults** — teams don't configure what they shouldn't need to
3. **Self-service** — any engineer can provision without senior approval
4. **Consistency** — every environment is identical in structure

## Audience Levels

### 🟢 Beginner
This is the end goal of everything in this series. Build modules, version them, call them from simple root configs. The payoff is exactly this: minutes instead of days.

### 🔵 Intermediate
Measure your current provisioning time. Set a target. Identify the top 3 repeated resource patterns and turn them into modules. Measure again after 3 months.

### 🟠 Advanced
Build an internal developer platform: a self-service portal where engineers fill in a form (project name, environment, size) and get a PR with the Terraform config auto-generated. Backstage.io + Terraform templates.

### 🔴 Expert
Platform engineering metrics: provisioning time P50/P95, configuration drift rate, time-to-detect security violations, module adoption rate. Present these to engineering leadership monthly. Infrastructure as a product.
