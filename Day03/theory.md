# Day 03 — Providers, Resources & State Explained

## 5W + 1H Framework

### WHO
- All Terraform users — these three concepts are fundamental to everything else
- This is the conceptual foundation that all future days build upon

### WHAT

#### 1. Providers
A **provider** is a plugin that knows how to communicate with a specific API or platform. It implements CRUD operations for each resource type it supports.

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"   # Registry path: registry.terraform.io/hashicorp/aws
      version = "~> 5.0"          # Constraint: >= 5.0, < 6.0
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  # Credentials: from environment, ~/.aws/credentials, or IAM role
}
```

#### 2. Resources
A **resource** represents a single infrastructure object (a VPC, an EC2 instance, an S3 bucket).

```hcl
# Syntax: resource "TYPE" "NAME" { ... }
# TYPE = <provider>_<resource> e.g. aws_vpc, google_compute_instance
# NAME = your local reference name (used within Terraform only)

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Reference: aws_vpc.main.id
```

**Resource lifecycle arguments** (meta-arguments):
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"

  # Meta-arguments — control Terraform's behavior, not the resource itself
  depends_on = [aws_vpc.main]    # Explicit dependency
  count      = 3                  # Create 3 instances
  
  lifecycle {
    create_before_destroy = true  # Create new before destroying old
    prevent_destroy       = true  # Terraform will refuse to destroy this resource
    ignore_changes        = [tags] # Ignore tag changes made outside Terraform
  }
}
```

#### 3. State
The **state file** (`terraform.tfstate`) is a JSON document that maps your Terraform resources to real infrastructure objects.

```json
{
  "version": 4,
  "terraform_version": "1.6.0",
  "lineage": "a1b2c3d4-...",
  "resources": [
    {
      "mode": "managed",
      "type": "aws_vpc",
      "name": "main",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "attributes": {
            "id": "vpc-0abc123456789",
            "cidr_block": "10.0.0.0/16",
            "arn": "arn:aws:ec2:us-east-1:123456789012:vpc/vpc-0abc123456789"
          }
        }
      ]
    }
  ]
}
```

### WHEN
- **Providers:** Configured once per project; re-initialized when you add new providers
- **Resources:** Defined for every piece of infrastructure you want to manage
- **State:** Automatically managed by Terraform; consulted on every plan/apply

### WHERE
- **Providers:** Downloaded to `.terraform/providers/` on `terraform init`
- **Resources:** Defined in `.tf` files; exist as real infrastructure in the cloud
- **State:** Stored locally (`terraform.tfstate`) or remotely (S3, Terraform Cloud) — always remotely in teams

### WHY
- **Provider:** Abstraction layer — you write HCL, provider translates to API calls
- **Resource:** The unit of infrastructure management — one resource = one cloud object
- **State:** The "memory" of Terraform — without it, Terraform can't know what to update or delete

### HOW

**Provider initialization:**
```bash
terraform init
# Downloads providers to .terraform/providers/
# Creates .terraform.lock.hcl with exact versions
```

**Resource management flow:**
```
.tf file (desired state)
         ↓
terraform plan (diff vs. state + reality)
         ↓
terraform apply (modify reality)
         ↓
.tfstate (updated to reflect reality)
```

---

## Audience-Level Explanations

### 🟢 Beginner
**Provider** = The translator. AWS speaks a certain API language. The AWS provider translates your HCL into the right AWS API calls.

**Resource** = A thing in the cloud. An S3 bucket is a resource. A VPC is a resource. Each one gets its own `resource {}` block.

**State** = Terraform's notebook. After creating a VPC, Terraform writes down "I created vpc-0abc123". Next time, it checks its notebook to know what already exists.

### 🔵 Intermediate

**Multi-provider configuration:**
```hcl
# Use provider aliases for same provider, different regions
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

resource "aws_vpc" "us" {
  provider   = aws.us_east
  cidr_block = "10.0.0.0/16"
}

resource "aws_vpc" "eu" {
  provider   = aws.eu_west
  cidr_block = "10.1.0.0/16"
}
```

**State commands you need:**
```bash
terraform state list                    # List all resources in state
terraform state show aws_vpc.main       # Inspect a specific resource
terraform state mv aws_vpc.old aws_vpc.new  # Rename a resource in state
terraform state rm aws_instance.temp    # Remove from state (doesn't delete real infra)
terraform refresh                       # Sync state with real infrastructure
```

### 🟠 Advanced

**Provider version constraints explained:**
```hcl
version = "= 5.0.0"   # Exactly this version
version = ">= 5.0"    # At least 5.0
version = "~> 5.0"    # >= 5.0, < 6.0 (most common — allows patches)
version = "~> 5.0.3"  # >= 5.0.3, < 5.1.0 (strict patch-level)
```

**Resource dependency types:**
```hcl
# Implicit dependency — Terraform infers from references
resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id  # Implicit: subnet depends on VPC
}

# Explicit dependency — use when no reference exists
resource "aws_route" "internet" {
  depends_on = [aws_internet_gateway.main]
}
```

**State backend migration:**
```bash
# Moving from local to S3 backend:
# 1. Add backend config to terraform {}
# 2. Run terraform init -migrate-state
# 3. Confirm migration
```

**Sensitive state values:**
State can contain sensitive data (passwords, private keys). Always:
- Encrypt state at rest (S3 SSE)
- Restrict state access via IAM
- Never log or print state contents in CI/CD

### 🔴 Expert

**Provider internals:**
Each provider implements the Terraform Plugin Protocol (gRPC). The protocol defines:
- `GetSchema` — describes resource schemas and attributes
- `PlanResourceChange` — compute the diff
- `ApplyResourceChange` — create/update/delete the resource
- `ImportResourceState` — bring existing resources into state

**State format internals:**
The `.tfstate` JSON has:
- `lineage`: UUID preventing state from different projects merging
- `serial`: Monotonically increasing version number; DynamoDB lock key
- `terraform_version`: Minimum version that can read this state
- `check_results`: Results of custom condition checks (Terraform 1.5+)

**State locking protocol with DynamoDB:**
```
1. terraform apply starts
2. Writes LockInfo JSON to DynamoDB item (key: state path)
3. If item exists → lock held by someone else → wait/fail
4. Apply executes changes
5. Updates .tfstate in S3 (atomic S3 PutObject)
6. Deletes DynamoDB item (unlock)
```

**Custom provider development:**
```go
// Implement provider using Terraform Plugin Framework (Go)
func (r *VpcResource) Create(ctx context.Context, req resource.CreateRequest, resp *resource.CreateResponse) {
    var data VpcResourceModel
    resp.Diagnostics.Append(req.Plan.Get(ctx, &data)...)
    // Call AWS API...
    data.Id = types.StringValue(vpc.VpcId)
    resp.Diagnostics.Append(resp.State.Set(ctx, &data)...)
}
```

---

## State Management Best Practices

| Practice | Why |
|---|---|
| Always use remote backend in teams | Multiple people need access |
| Enable S3 versioning on state bucket | Rollback on corruption |
| Enable DynamoDB locking | Prevent concurrent apply |
| Encrypt state at rest (SSE) | State may contain secrets |
| Restrict state bucket access via IAM | Least privilege |
| Never manually edit `.tfstate` | JSON corruption risk |
| Use `terraform state` commands for changes | Safe state manipulation |
| Back up state before destructive operations | `aws s3 cp s3://bucket/state backup.tfstate` |
