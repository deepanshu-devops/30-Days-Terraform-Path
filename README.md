# 30-Day Terraform Learning Series

A comprehensive, production-grade Terraform learning series covering theory, implementation, and hands-on code for every skill level.

## Series Overview

| Week | Days | Topic |
|---|---|---|
| Week 1 | 01–07 | Foundations |
| Week 2 | 08–14 | State & Modules |
| Week 3 | 15–21 | CI/CD & Security |
| Week 4 | 22–26 | Real-World & Production |
| Wrap-up | 27–30 | Mistakes, Interviews, Resources |

## Folder Structure

```
DayXX/
  theory.md         # 5W+1H, concepts, audience-level explanations
  implementation.md # Step-by-step hands-on guide
  code/
    main.tf          # Complete, production-grade Terraform code
    terraform.tfvars.example  # (where applicable)
  examples/
    README.md        # Additional usage examples
```

## Prerequisites

- Terraform CLI >= 1.6.0
- AWS CLI configured (`aws configure`)
- AWS account (free tier sufficient for most days)
- Git

## Quick Start

```bash
# Day 01
cd Day01/code
terraform init
terraform plan
terraform apply
terraform destroy
```

## Audience Levels

Each day covers four skill levels:
- 🟢 **Beginner** — Clear analogies, minimal prerequisites
- 🔵 **Intermediate** — Patterns, best practices, team scenarios
- 🟠 **Advanced** — Production architecture, edge cases
- 🔴 **Expert** — Internals, at-scale considerations, engineering discipline

## Day Index

| Day | Topic |
|---|---|
| 01 | What is Terraform & Why IaC |
| 02 | Terraform vs CloudFormation vs Pulumi |
| 03 | Providers, Resources & State |
| 04 | Init → Plan → Apply → Destroy |
| 05 | Variables, Outputs & Locals |
| 06 | Data Sources & Dependencies |
| 07 | Functions & Expressions |
| 08 | Remote State: S3 + DynamoDB |
| 09 | State Corruption: Causes & Prevention |
| 10 | Writing Reusable Modules |
| 11 | Module Versioning |
| 12 | Workspaces vs tfvars |
| 13 | count, for_each & Dynamic Blocks |
| 14 | Terraform Import |
| 15 | CI/CD: GitHub Actions & Jenkins |
| 16 | Secrets Management |
| 17 | IAM Least Privilege |
| 18 | Policy as Code: Sentinel & OPA |
| 19 | Security Scanning: Checkov & tfsec |
| 20 | Testing with Terratest |
| 21 | Multi-Account AWS |
| 22 | EKS End-to-End |
| 23 | RDS Multi-AZ |
| 24 | Case Study: 48h → 30min |
| 25 | Drift Detection |
| 26 | Cost Estimation with Infracost |
| 27 | Top 5 Mistakes |
| 28 | Interview Questions |
| 29 | Learning Resources |
| 30 | Series Recap & What's Next |

## Cost Warning

Some configurations (EKS, RDS Multi-AZ, NAT Gateways) create resources that cost money. Resources are commented out or marked with warnings where applicable. Always run `terraform destroy` after learning exercises.

## Series by Deepanshu Kushwaha | DevOps Engineer
