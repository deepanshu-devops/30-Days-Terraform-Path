# Day 28 — Terraform Interview Questions (Real Ones)

## Foundational Questions

**Q: What is the difference between `terraform plan` and `terraform apply`?**
A: `plan` shows what Terraform *would* do without making any changes — it diffs desired state (config) vs current state (tfstate + real infra). `apply` executes those changes. Always review plan before apply. In production CI/CD: plan runs on PR, apply runs on merge with human approval.

**Q: Explain Terraform state and why it matters.**
A: State is a JSON file mapping resource blocks to real cloud objects. Without it, Terraform can't know what exists, what to update, or what to delete. State is the source of truth. In teams: always store remotely (S3), always lock (DynamoDB), always encrypt.

**Q: What is a Terraform provider?**
A: A plugin that implements CRUD operations for a specific API. The AWS provider translates HCL into AWS API calls. Providers are downloaded by `terraform init` and pinned in `.terraform.lock.hcl`.

## Intermediate Questions

**Q: How do you manage Terraform state in a team environment?**
A: Remote backend (S3 for AWS), DynamoDB for state locking, S3 versioning enabled, SSE encryption, IAM-restricted access. Never local state in team environments.

**Q: What is a Terraform module and why use one?**
A: A module is a directory of Terraform files designed for reuse. Use modules to eliminate duplication, enforce consistency, and enable self-service infrastructure. Treat modules like APIs: version them, document them, test them.

**Q: What is the difference between `count` and `for_each`?**
A: Both create multiple resource instances. `count` uses numeric indices — removing item 0 cascades destruction to all subsequent. `for_each` uses stable string keys — removing one key only destroys that one resource. Prefer `for_each` for almost everything.

**Q: How do you handle secrets in Terraform?**
A: AWS Secrets Manager or HashiCorp Vault data sources. Mark sensitive outputs with `sensitive = true`. Never put secrets in `.tfvars` files committed to Git. Encrypt state at rest.

**Q: What happens if two people run `terraform apply` at the same time?**
A: Without locking: state corruption (both write to state simultaneously). With DynamoDB locking: the second apply blocks until the first finishes.

## Advanced Questions

**Q: What is `terraform import` and when would you use it?**
A: Brings existing resources into Terraform state without recreating them. Used when inheriting manually-created infrastructure, recovering from state corruption, or migrating from another IaC tool. Terraform 1.5+ adds declarative `import {}` blocks and `-generate-config-out` flag.

**Q: How do you test Terraform code?**
A: Layered approach: `terraform validate` (syntax), `terraform plan` (logic), `checkov`/`tfsec` (security scanning), Terratest (integration tests that deploy and validate real infra), Infracost (cost validation).

**Q: What is IRSA and why is it better than node instance profiles for EKS?**
A: IRSA (IAM Roles for Service Accounts) binds IAM roles to Kubernetes service accounts via OIDC. Each pod gets exactly the permissions it needs. With instance profiles, all pods on a node share the same IAM role — violating least privilege.

**Q: How would you handle a Terraform state corruption incident?**
A: 1) Stop all applies immediately, 2) Check S3 versioning for a recent good state, 3) Restore the state, 4) Run `terraform plan` to verify accuracy, 5) For partial corruption: use `terraform state rm` / `terraform import` to fix individual resources, 6) Post-incident: ensure DynamoDB locking was enabled.

## Expert Questions

**Q: Explain the Terraform provider plugin protocol.**
A: Providers communicate with the Terraform core via gRPC (Plugin Protocol v5/v6). The provider binary implements: `GetSchema`, `PlanResourceChange`, `ApplyResourceChange`, `ImportResourceState`. The core calls these via the plugin protocol. Plugin Framework (successor to SDKv2) uses Protocol v6.

**Q: How does Terraform build its execution plan?**
A: Builds a DAG (Directed Acyclic Graph) from resource references. Walks the graph calling `provider.ReadResource` for each existing resource (refresh). Diffs desired vs refreshed state. Produces an ordered execution plan respecting dependencies. Independent resources are created in parallel (up to `-parallelism=N`).

**Q: What is the `.terraform.lock.hcl` file?**
A: Lockfile recording exact provider versions and checksums after `terraform init`. Commit this to Git — it ensures all team members and CI/CD use identical provider versions regardless of constraint expressions in config.
