# Day 28 — Terraform Interview Questions

## Real-Life Example 🏗️

These are questions I was actually asked in interviews for senior DevOps and platform engineering roles. The answers that worked are included. What distinguishes a good answer from a great one: concrete examples from production experience.

---

## Foundational Questions

**Q: What is Terraform state and why does it matter?**

State is a JSON file that maps your HCL resource blocks to real AWS resource IDs. Terraform uses it to know: what exists (so it doesn't recreate), what changed (so it only updates what's needed), and what to delete (so it can clean up).

Without state: every `apply` would try to create everything from scratch.

In teams: store state remotely (S3), lock it during apply (DynamoDB), encrypt it at rest (KMS), enable versioning (S3 versioning). Local state in a team environment always leads to a corruption incident — usually within 3 months.

**Q: Explain the difference between `terraform plan` and `terraform apply`.**

`plan` is a preview — it calls AWS read-only APIs to diff desired state (code) vs known state (state file) vs real infra, then shows what would change. No writes.

`apply` executes the plan. Makes real API calls. Writes to state.

In production CI/CD: plan runs on PR and is posted as a comment so reviewers see the impact. Apply runs on merge to main, after human review and approval. Never apply without reviewing the plan.

**Q: What is a Terraform provider?**

A plugin that implements CRUD operations for a specific API. The AWS provider translates your HCL into AWS API calls. Providers are separate binaries downloaded by `terraform init` to `.terraform/providers/`. Version pinned in `.terraform.lock.hcl` (which you commit to Git).

---

## Intermediate Questions

**Q: `count` vs `for_each` — when do you use each?**

`count` for simple numbered resources where you won't remove items from the middle. `for_each` for everything else — it uses stable string keys, so removing one item only destroys that resource without affecting others.

Real-life: I switched a project from `count` to `for_each` after a subnet removal destroyed 3 EC2 instances because their indices shifted. Never used `count` for collections after that.

**Q: How do you manage state in a team?**

S3 backend, DynamoDB locking, S3 versioning, KMS encryption, IAM-restricted access. We also set up a nightly drift detection pipeline that runs `terraform plan -detailed-exitcode` and pages us if exit code 2 (changes detected).

**Q: What's a Terraform module and why use one?**

A directory of `.tf` files designed for reuse — variables.tf (inputs), main.tf (resources), outputs.tf (outputs). No provider block, no backend.

At Amdocs: built a module library for VPC, EKS, RDS, ALB, IAM. Reduced environment provisioning from 48 hours to 30 minutes. Any engineer can now provision from a 40-line root config.

**Q: How do you handle secrets?**

AWS Secrets Manager data sources (`data "aws_secretsmanager_secret_version"`). Mark sensitive outputs with `sensitive = true`. Encrypt state with KMS. `*.tfvars` in `.gitignore`. CI/CD injects secrets via `TF_VAR_x` environment variables, never stored in files.

---

## Advanced Questions

**Q: What is `terraform import` and when do you use it?**

Brings existing infrastructure into Terraform state without recreating it. Used when adopting manually-created resources or recovering from state corruption.

Terraform 1.5+ added declarative `import {}` blocks: define the import in code, run `terraform plan -generate-config-out=generated.tf`, and Terraform writes the resource config for you.

**Q: Two people run `terraform apply` simultaneously. What happens?**

Without DynamoDB locking: both read the same state version, both apply, one overwrites the other's state. State corruption. Potentially missing or duplicate resources.

With locking: the second apply sees the DynamoDB lock item, waits or fails with "state is locked by [engineer] since [time]". Apply safely serialised.

**Q: What is IRSA and why is it better than EC2 instance profiles for EKS?**

IRSA (IAM Roles for Service Accounts) binds an IAM role to a specific Kubernetes service account. Each pod gets its own scoped role. With instance profiles, all pods on a node share the same IAM role — violating least privilege. A compromised pod gets full node-level AWS access.

---

## Expert Questions

**Q: Explain the Terraform dependency graph.**

Terraform builds a DAG (Directed Acyclic Graph) from resource references. `aws_subnet.main` references `aws_vpc.main.id` → creates VPC before subnet. Independent resources run in parallel (up to `-parallelism=N`, default 10). `terraform graph | dot -Tsvg > graph.svg` visualises it.

**Q: What is `.terraform.lock.hcl` and should you commit it?**

Records exact provider versions (not just constraints) and checksums after `terraform init`. YES, commit it. It ensures every engineer and every CI/CD runner uses identical provider binaries regardless of when they run init. Without it: "works on my machine" with different provider behaviour.

**Q: How do you test Terraform code?**

Three layers:
1. `terraform validate` + `checkov`/`tfsec` — syntax and security (seconds, free)
2. `terraform plan` — logic check in CI on every PR (30 seconds, free)
3. Terratest — integration test that deploys real infra, validates outputs, destroys (5-20 minutes, ~$0.10/run)

All three. Never skip any layer.
