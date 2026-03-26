# Day 01 — What is Terraform & Why Infrastructure as Code?

## 5W + 1H Framework

### WHO
- **Who uses Terraform?**
  - DevOps Engineers managing cloud infrastructure
  - Platform Engineers building internal developer platforms
  - SREs (Site Reliability Engineers) ensuring system reliability
  - Cloud Architects designing scalable systems
  - Developers in DevOps-heavy teams owning their own infrastructure

### WHAT
- **What is Terraform?**
  - An open-source Infrastructure as Code (IaC) tool created by HashiCorp (2014)
  - Uses **HCL (HashiCorp Configuration Language)** — a declarative, human-readable language
  - Allows you to define, provision, and manage infrastructure across any cloud provider
  - Maintains a **state file** that tracks the real-world infrastructure it manages

- **What is Infrastructure as Code (IaC)?**
  - The practice of managing and provisioning infrastructure through machine-readable configuration files instead of manual processes
  - Infra lives in Git — versionable, reviewable, auditable

### WHEN
- **When should you use Terraform?**
  - Any time you provision cloud resources (EC2, VPCs, RDS, EKS, etc.)
  - When you need identical environments (dev, staging, prod)
  - When multiple engineers manage the same infrastructure
  - When you need audit trails for infrastructure changes
  - When you need repeatable, disaster-recovery-ready infrastructure

### WHERE
- **Where does Terraform run?**
  - Locally (developer laptop) — for learning and development
  - CI/CD pipelines (GitHub Actions, Jenkins, GitLab CI) — for production
  - Terraform Cloud / Terraform Enterprise — for team collaboration

- **Where does it manage infrastructure?**
  - AWS, Azure, GCP, Oracle Cloud
  - Kubernetes, Helm
  - Cloudflare, Datadog, PagerDuty
  - 3,000+ providers in the Terraform Registry

### WHY
- **Why Terraform over manual provisioning?**

| Manual (Console) | Terraform (IaC) |
|---|---|
| Click-driven, error-prone | Code-driven, repeatable |
| No audit trail | Full Git history |
| Hours to days per environment | Minutes per environment |
| "Works on my environment" | Identical across all envs |
| Hard to disaster recover | Rebuild from code in minutes |
| No peer review | PR-reviewed infra changes |

### HOW
- **How does Terraform work?**
  1. You write `.tf` files describing desired infrastructure
  2. `terraform init` downloads providers
  3. `terraform plan` shows what will change
  4. `terraform apply` creates/updates real infrastructure
  5. Terraform writes state to track what it manages

---

## Audience-Level Explanations

### 🟢 Beginner
Terraform is like a recipe for your cloud infrastructure. Instead of logging into AWS and clicking "Create VPC", you write a recipe:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

Run `terraform apply` and Terraform cooks it for you. Want the same VPC in 5 regions? Run the same recipe 5 times. Consistently. Perfectly.

**Key takeaway:** Terraform replaces clicking in cloud consoles with writing code.

---

### 🔵 Intermediate
Terraform is a **declarative** IaC tool. You describe *what* you want, not *how* to create it. Terraform figures out the API calls, the sequencing, and the dependencies.

- **Declarative:** "I want an S3 bucket with encryption" — Terraform figures out the API calls
- **Idempotent:** Running `apply` 10 times produces the same result
- **Dependency-aware:** Terraform builds a dependency graph (DAG) and creates resources in the right order

The **state file** (`terraform.tfstate`) is how Terraform maps your config to real resources. It knows: "This `aws_vpc.main` block corresponds to vpc-0abc123456 in AWS."

---

### 🟠 Advanced
Terraform's core engine works through a **dependency graph (DAG — Directed Acyclic Graph)**:

1. Parses all `.tf` files into an internal representation
2. Builds a resource graph based on references (`aws_subnet.main` depends on `aws_vpc.main.id`)
3. Runs `plan`: diffs desired state (config) vs known state (`.tfstate`) vs real state (cloud APIs)
4. Runs `apply`: walks the DAG and parallelizes independent resource creation

**Providers** are plugins written in Go that implement CRUD operations for each resource type. They communicate via gRPC to the Terraform core.

State drift (real infra diverging from state) is the core operational challenge. We address this with remote state, locking, and scheduled drift detection.

---

### 🔴 Expert
Terraform's architecture consists of:
- **Core:** The `terraform` binary — graph builder, state machine, RPC client
- **Providers:** Separate binaries discovered at `~/.terraform.d/plugins/` — implement `ResourceServer` gRPC interface
- **State:** JSON file tracking resource identity mapping; the `lineage` field prevents state merges across different root modules

At scale, the critical operational concerns are:
- **State backend selection:** S3+DynamoDB (AWS), GCS+Cloud Spanner (GCP), or Terraform Cloud
- **State size management:** Large states (10K+ resources) cause slow plan times — use workspaces or separate root modules to partition
- **Provider version pinning:** `required_providers` with exact or `~>` constraints in `.terraform.lock.hcl`
- **Parallelism tuning:** `terraform apply -parallelism=N` (default 10) — tune based on API rate limits

The **Terraform Plugin Framework** (replacement for SDKv2) uses the new Protocol v6, enabling features like null-safe attribute values and nested attributes.

---

## Key Concepts Summary

| Concept | Description |
|---|---|
| HCL | HashiCorp Configuration Language — the syntax for `.tf` files |
| Provider | Plugin that talks to a cloud/service API |
| Resource | A piece of infrastructure (VPC, EC2, S3) |
| State | Terraform's record of managed infrastructure |
| Plan | Preview of changes before applying |
| Apply | Execute changes |
| Module | Reusable group of resources |
| Backend | Where state is stored (local, S3, Terraform Cloud) |

---

## Common Misconceptions

1. **"Terraform is only for AWS"** — False. 3,000+ providers exist
2. **"Terraform requires deep cloud knowledge"** — False for basics; but deep knowledge matters for production
3. **"Once applied, my infra is safe"** — False. Drift, manual changes, and state corruption are real risks
4. **"Terraform manages everything automatically"** — False. Day-2 operations (patching, scaling events) still need orchestration

---

## Production Best Practices (Day 01 Level)

- Never store `terraform.tfstate` locally for team projects
- Always run `terraform plan` before `apply`
- Keep Terraform version pinned in `required_version`
- Store `.tf` files in Git — infra as code means Git is the source of truth
