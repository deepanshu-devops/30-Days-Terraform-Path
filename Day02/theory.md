# Day 02 — Terraform vs CloudFormation vs Pulumi

## 5W + 1H Framework

### WHO
- Platform teams evaluating IaC tooling for their organization
- DevOps engineers transitioning from one tool to another
- Engineering managers making technology decisions
- Cloud architects designing greenfield infrastructure strategies

### WHAT
Three dominant IaC tools, each with distinct philosophies:

| Feature | Terraform | CloudFormation | Pulumi |
|---|---|---|---|
| Creator | HashiCorp | AWS | Pulumi Corp |
| Language | HCL (declarative) | YAML/JSON (declarative) | Python, TypeScript, Go, C#, Java |
| Cloud Scope | Multi-cloud (3,000+ providers) | AWS-only (deep native) | Multi-cloud |
| State Management | Self-managed (S3, etc.) | AWS-managed | Pulumi Cloud or self-hosted |
| Cost | Open Source (free) + Terraform Cloud | Free (native AWS) | Free tier + Pulumi Cloud |
| Community | Largest | AWS community | Growing |
| Maturity | High (2014) | High (2011) | Medium (2018) |

### WHEN
- **Choose Terraform when:**
  - Multi-cloud or hybrid cloud strategy
  - Team already knows HCL
  - Maximum community support needed
  - Large ecosystem of community modules required

- **Choose CloudFormation when:**
  - 100% AWS-only, no plans to multi-cloud
  - Want zero state management overhead
  - Deep AWS service integrations needed (StackSets, Service Catalog)

- **Choose Pulumi when:**
  - Developer-heavy team that resists HCL
  - Need real programming loops, conditionals, abstractions
  - Existing SDK expertise (TypeScript, Python)

### WHERE
- **Terraform:** Works everywhere — any cloud, any on-prem, any SaaS
- **CloudFormation:** AWS only, but deeply integrated (all AWS services supported on day 1)
- **Pulumi:** Multi-cloud, supports same providers as Terraform via bridge

### WHY
- **Why not just use the cloud CLI/SDK?** IaC provides declarative intent, idempotency, drift detection, and team collaboration
- **Why Terraform leads adoption:** It was first, it's multi-cloud, and the community is enormous

### HOW
Each tool follows the same conceptual flow but implements it differently:
```
Terraform:         HCL → terraform plan → terraform apply
CloudFormation:    YAML → aws cloudformation deploy
Pulumi:            TypeScript/Python → pulumi preview → pulumi up
```

---

## Audience-Level Explanations

### 🟢 Beginner
Think of all three as different "languages" for describing what cloud infrastructure you want. They all do the same thing — tell the cloud "create me a VPC, an EC2, an S3 bucket" — but they speak differently.

**Terraform** uses its own simple language (HCL). **CloudFormation** uses YAML or JSON (lots of boilerplate). **Pulumi** uses real programming languages like Python.

For beginners: **Start with Terraform.** It's the most in-demand, best documented, and the community can answer almost any question you have.

### 🔵 Intermediate

**Terraform's strength** is the provider ecosystem. Need to manage AWS + Cloudflare DNS + Datadog monitors in one config? Terraform handles it.

**CloudFormation's strength** is native integration. New AWS services are supported in CloudFormation on day 1, sometimes before Terraform's provider catches up. Also: no state file to manage — AWS handles it.

**Pulumi's strength** is programmability. Need a loop that creates 50 S3 buckets with different configs based on a CSV? Write a for loop. Terraform's `for_each` can handle this, but Pulumi makes it more natural for developers.

The key tradeoff: **Terraform** has the biggest ecosystem and multi-cloud support. **CloudFormation** has zero ops overhead for state. **Pulumi** has real language power.

### 🟠 Advanced

**Terraform at scale:**
- State partitioning strategy critical (monorepo vs. microstate)
- Provider version locking with `.terraform.lock.hcl`
- Terragrunt as a DRY wrapper pattern
- CDKTF (Cloud Development Kit for Terraform) brings Pulumi-like programmability to Terraform

**CloudFormation at scale:**
- StackSets for multi-account, multi-region deployments
- Service Catalog for self-service infra
- CloudFormation Hooks for pre/post resource actions (equivalent to Sentinel)
- Change Sets = CloudFormation's equivalent of `terraform plan`

**Pulumi at scale:**
- Component Resources for module-like abstraction
- Pulumi Automation API: embed Pulumi in your own Go/Python programs
- Stack references = cross-stack outputs (equivalent to Terraform remote state data source)

**State management comparison:**
```
Terraform:       .tfstate (JSON) → S3 + DynamoDB lock (self-managed)
CloudFormation:  AWS-managed, no state file visible
Pulumi:          Checkpoint files → Pulumi Cloud or S3
```

### 🔴 Expert

**Architectural differences at the core:**

Terraform uses a **graph-based execution model** — builds a DAG and parallelizes independent resources. CloudFormation uses a **stack-based model** with explicit DependsOn relationships. Pulumi builds the graph dynamically at runtime based on actual code execution.

**Provider architecture:**
- Terraform: gRPC-based plugin protocol. Providers are separate binaries.
- CloudFormation: Resource Types via CloudFormation Extension Registry (Go/Java/Python handlers via CloudFormation CLI)
- Pulumi: Uses Terraform providers via `pulumi-terraform-bridge` for most resources; native providers written with Pulumi SDK

**State reconciliation:**
- Terraform: Reads state, calls cloud APIs to diff, generates ordered plan
- CloudFormation: AWS maintains the stack graph; you get rollback on failure automatically
- Pulumi: Same as Terraform but the state checkpoint also captures resource URNs

**When to use each in enterprise:**
- Terraform: Platform team manages modules; application teams consume them. Works well with Atlantis (GitOps for Terraform).
- CloudFormation: AWS Organizations + Service Control Policies + StackSets for governance at org level.
- Pulumi: When application teams want to define infra in the same language as their app code (TypeScript monorepo).

---

## Side-by-Side Code Comparison

### Create an S3 Bucket with Encryption

**Terraform (HCL):**
```hcl
resource "aws_s3_bucket" "logs" {
  bucket = "my-app-logs-${var.environment}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**CloudFormation (YAML):**
```yaml
Resources:
  LogsBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub "my-app-logs-${Environment}"
      BucketEncryption:
        ServerSideEncryptionConfiguration:
          - ServerSideEncryptionByDefault:
              SSEAlgorithm: AES256
```

**Pulumi (TypeScript):**
```typescript
import * as aws from "@pulumi/aws";

const bucket = new aws.s3.BucketV2("logs", {
  bucket: `my-app-logs-${environment}`,
});

new aws.s3.BucketServerSideEncryptionConfigurationV2("logsEncryption", {
  bucket: bucket.id,
  rules: [{
    applyServerSideEncryptionByDefault: {
      sseAlgorithm: "AES256",
    },
  }],
});
```

---

## Decision Matrix

| Criterion | Weight | Terraform | CloudFormation | Pulumi |
|---|---|---|---|---|
| Multi-cloud support | High | ✅ Best | ❌ AWS only | ✅ Good |
| Community & modules | High | ✅ Largest | ✅ AWS-focused | ⚠️ Growing |
| State management overhead | Medium | ⚠️ Self-managed | ✅ None | ⚠️ Self or cloud |
| Language familiarity | Medium | ⚠️ HCL (learn it) | ⚠️ YAML | ✅ Python/TS/Go |
| AWS-native features | Medium | ⚠️ Lag on new services | ✅ Day-1 support | ⚠️ Via bridge |
| Enterprise governance | High | ✅ Sentinel/OPA | ✅ CloudFormation Hooks | ✅ Policies |
| Job market demand | High | ✅ Highest | ✅ AWS-specific | ⚠️ Niche |

**Verdict for most teams:** Terraform.
