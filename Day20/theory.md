# Day 20 — Terraform Testing with Terratest

## WHAT
Terratest is a Go library for writing automated tests for Terraform modules. It deploys real infrastructure, validates it works, then destroys it.

## Test Types

### 1. Unit Tests (terraform validate + plan)
```bash
terraform validate   # Syntax check
terraform plan       # Logic check — no real infra
```

### 2. Integration Tests with Terratest
```go
// test/vpc_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVpcModule(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/vpc",
        Vars: map[string]interface{}{
            "name":               "test-vpc",
            "cidr_block":         "10.0.0.0/16",
            "availability_zones": []string{"us-east-1a", "us-east-1b"},
            "public_subnet_cidrs": []string{"10.0.1.0/24", "10.0.2.0/24"},
        },
        EnvVars: map[string]string{
            "AWS_DEFAULT_REGION": "us-east-1",
        },
    }

    // Ensure destroy runs even if test fails
    defer terraform.Destroy(t, terraformOptions)

    // Deploy
    terraform.InitAndApply(t, terraformOptions)

    // Validate outputs
    vpcID := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcID, "VPC ID should not be empty")
    assert.Regexp(t, "^vpc-", vpcID, "VPC ID should start with vpc-")

    subnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
    assert.Equal(t, 2, len(subnetIDs), "Should have 2 public subnets")
}
```

```bash
# Run tests
cd test
go test -v -timeout 30m ./...

# Run a specific test
go test -v -run TestVpcModule -timeout 30m ./...
```

### 3. Checkov for Policy Tests
```bash
checkov -d ./modules/vpc --framework terraform
# Fails CI if any HIGH/CRITICAL findings
```

## Test Pyramid

```
         /\
        /  \
       / E2E\     Full environment tests (slow, expensive)
      /------\
     /  Integ \   Terratest module tests (minutes)
    /----------\
   /    Unit    \  validate + plan (seconds, free)
  /--------------\
```

---

## Audience Levels

### 🟢 Beginner
Start with `terraform validate` and `terraform plan` in CI. That catches 80% of issues. Graduate to Terratest when you have stable modules.

### 🔵 Intermediate
Write one Terratest test per module. Run them on PR to the module repo. Use `t.Parallel()` to run tests concurrently. Use separate AWS account for test runs.

### 🟠 Advanced
Use `terraform-docs` to auto-generate README. Use `tflint` for additional linting. Build a test fixture pattern: modules have a `test/fixtures/` directory with minimal configs for testing.

### 🔴 Expert
Build a test pipeline: validate → plan → security scan → cost estimate → integration test → promote to staging. Use AWS Nuke or Terratest's `aws.DeleteAllResourcesInRegion()` to clean up orphaned test resources.
