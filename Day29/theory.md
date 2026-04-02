# Day 29 — Learning Resources & Recommended Path

## Real-Life Example 🏗️

**The tutorial trap:**  
I spent my first month watching Terraform videos. Lots of them. I felt like I was learning.

Then I tried to provision a real VPC from scratch and got stuck on every step. The tutorials had taught me what Terraform was, not how to actually use it.

The breakthrough: I stopped watching and started building. Made mistakes. Broke state. Recovered it. Built a module. Broke the module. Fixed it.

I learned more from my first state corruption incident than from 20 hours of tutorials.

---

## The Path That Actually Works

```
Week 1-2:   Official tutorials on developer.hashicorp.com
            → Build in a real AWS account (free tier is enough)
            → Don't skip steps, run every command

Week 3-4:   Personal project
            → Your own VPC + EC2 + S3 bucket
            → Add remote state
            → Break something and fix it

Month 2:    Add CI/CD
            → GitHub Actions pipeline (Day 15)
            → Plan on PR, apply on merge

Month 3:    Write your first module
            → Extract the VPC code into modules/vpc/
            → Call it from a root module
            → Test it

Month 4:    Contribute to your team
            → Build a module they can use
            → Code review someone else's Terraform

Month 5+:   Own a module library or a platform
```

---

## Free Resources

### Official (Start Here)
```
developer.hashicorp.com/terraform/tutorials
  → Interactive labs with real infrastructure
  → Best Terraform tutorial series available

registry.terraform.io
  → Provider documentation (the AWS provider docs are excellent)
  → Community modules to study (read the source code)
  → Search for any resource type you're working with
```

### GitHub Repositories to Study
```
github.com/terraform-aws-modules
  → Production-grade community modules
  → Read the source code — learn patterns from the best

github.com/gruntwork-io/terratest
  → Testing examples, test patterns

github.com/antonputra/tutorials
  → Deep Terraform + AWS tutorials with full code
```

### YouTube Channels
```
Anton Putra         → Deep dives, production setups, EKS, security
TechWorld with Nana → Visual concept explanations, great for starters
HashiCorp official  → Tool announcements, HashiConf talks
```

---

## Books Worth Buying

**Terraform: Up & Running** by Yevgeniy Brikman (O'Reilly, 3rd edition)  
The best Terraform book. Practical, production-focused, covers real teams and real problems. Read it after you've done the basics so the problems it solves make sense.

**Infrastructure as Code** by Kief Morris (O'Reilly, 2nd edition)  
Tool-agnostic. Explains the principles behind all IaC tools. Makes you understand *why*, not just *how*.

---

## Certifications Worth Taking

| Cert | Level | Value |
|------|-------|-------|
| HashiCorp Terraform Associate (003) | Beginner-Intermediate | Validates core knowledge, well-recognised |
| AWS Solutions Architect Associate | Intermediate | Essential context for Terraform on AWS |
| AWS DevOps Professional | Advanced | CI/CD, IaC, monitoring in depth |

Study for the Terraform Associate *while* building projects. The exam tests practical knowledge.

---

## Practice Without Spending Money: LocalStack

```bash
# Run AWS services locally in Docker
docker run --rm -p 4566:4566 localstack/localstack

# Configure Terraform to use LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock"
  secret_key                  = "mock"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  endpoints {
    s3       = "http://localhost:4566"
    ec2      = "http://localhost:4566"
    iam      = "http://localhost:4566"
    dynamodb = "http://localhost:4566"
  }
}
```

Practice `init`, `plan`, `apply`, `state` commands without paying AWS.

---

## What Didn't Work For Me

| What I tried | Why it failed |
|-------------|--------------|
| Watching videos without building | Passive consumption. Felt productive. Wasn't. |
| Tutorial hell | Did the same intro tutorial 3 times instead of building something real |
| Reading docs before trying | Context-free reading doesn't stick |
| Avoiding mistakes | "I don't want to break anything" → you don't learn anything |
| Building everything from scratch | Better to read a mature module, then build your own |

---

## Tools to Learn After Terraform

```
Terragrunt    → DRY wrapper for Terraform (handles remote state, env management)
Atlantis      → GitOps for Terraform (runs plan on PRs, apply on merge, full audit)
CDKTF         → Terraform with TypeScript/Python/Go instead of HCL
Terratest     → Integration testing for modules
terraform-docs → Auto-generate README from variables.tf and outputs.tf
tflint        → Additional linting beyond terraform validate
infracost     → Cost estimation in CI/CD (Day 26)
```
