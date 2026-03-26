# Day 29 — Learning Resources & Recommended Path

## The Path That Works

```
1. Official Docs → 2. Hands-on Labs → 3. Personal Project → 4. Contribute to Team → 5. Own the Platform
```

---

## Free Resources

### HashiCorp Official
- **developer.hashicorp.com/terraform** — Start here. Interactive tutorials with real infra.
- **registry.terraform.io** — Provider docs, community modules, public registry
- **developer.hashicorp.com/terraform/language** — HCL language reference

### GitHub Organizations
- **github.com/terraform-aws-modules** — Production-grade community modules. Read the source code.
- **github.com/gruntwork-io/terratest** — Testing framework + examples
- **github.com/infracost/infracost** — Cost estimation tool

### YouTube Channels
- **Anton Putra** — Deep Terraform + AWS, production-focused
- **TechWorld with Nana** — Visual explainers, great for concepts
- **HashiCorp official channel** — Tool announcements, HashiConf talks

---

## Books

- **Terraform: Up & Running** by Yevgeniy Brikman (3rd edition) — The best Terraform book. Practical, production-focused.
- **Cloud Native Infrastructure** by Justin Garrison & Kris Nova — IaC in context of cloud native
- **Infrastructure as Code** by Kief Morris — Tool-agnostic IaC philosophy

---

## Practice Environments

```bash
# Free AWS tier is enough for most learning
# Key services: VPC, EC2, S3, IAM, RDS (smallest instances)

# LocalStack: run AWS locally (free tier for most services)
docker run --rm -p 4566:4566 localstack/localstack

# Configure Terraform to use LocalStack
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "mock_access_key"
  secret_key                  = "mock_secret_key"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    s3  = "http://localhost:4566"
    ec2 = "http://localhost:4566"
    iam = "http://localhost:4566"
  }
}
```

---

## Certifications

| Certification | Level | Value |
|---|---|---|
| HashiCorp Terraform Associate | Beginner-Intermediate | High — validates core knowledge |
| HashiCorp Terraform Professional | Advanced | Emerging |
| AWS Solutions Architect Associate | Intermediate | High — context for Terraform |
| AWS DevOps Professional | Advanced | High — CI/CD + IaC focus |

---

## Learning Anti-Patterns

- **Passive video watching without building** — feels productive, isn't. Build something after every concept.
- **Tutorial hell** — doing the same beginner tutorial 3 times instead of building a real project
- **Avoiding mistakes** — state corruption, failed applies teach more than tutorials
- **Learning in isolation** — contribute to your team's module library; code review accelerates learning

---

## Audience Levels

### 🟢 Beginner
Week 1: HashiCorp tutorials (VPC, EC2). Week 2: build a personal project (your own VPC + EC2). Week 3: add S3 remote state. Week 4: add CI/CD. That's a complete foundation.

### 🔵 Intermediate
Read the `terraform-aws-modules/vpc` source code. Understand every line. Then write your own VPC module from scratch. That exercise teaches more than 10 tutorials.

### 🟠 Advanced
Contribute an open-source module or a Terratest example. Teach a team member. Write a blog post. Learning in public accelerates mastery.

### 🔴 Expert
Build the platform. Design the module library. Establish the standards. Write the runbooks. Mentor the juniors. The best learning at this level is teaching.
