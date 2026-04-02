# Day 20 — Terraform Testing with Terratest

## Real-Life Example 🏗️

**The Broken Module Release:**  
You update the shared VPC module to support IPv6. You tag v1.3.0. Teams start upgrading.

Three teams report the same bug: subnets are being created in the wrong availability zones. The `element()` function in your fix has an off-by-one error that only shows up with 3+ AZs.

You never tested with 3 AZs before tagging. Now you need v1.3.1 and 3 teams need emergency rollbacks.

**With Terratest:**  
Before tagging v1.3.0, your CI pipeline deploys the module to a real AWS account with 3 AZs, checks that `subnet[0].availability_zone == "us-east-1a"`, runs assertions on all outputs, then destroys everything. The off-by-one is caught. v1.3.0 is never tagged.

---

## Testing Pyramid for Terraform

```
Level 3 — Integration Tests (Terratest)
  Deploy real infra → validate it works → destroy
  Time: 5-20 minutes | Cost: ~$0.10 per run
  When: On PR to main, before module version tagging

Level 2 — Logic Tests (terraform plan)
  Run plan and check output → no real infra
  Time: 30-60 seconds | Cost: free
  When: On every PR and commit

Level 1 — Syntax/Security (validate + checkov)
  Check syntax, linting, security rules
  Time: 5-15 seconds | Cost: free
  When: On every commit, pre-commit hooks
```

Run all three layers. Don't skip any.

---

## Terratest: Go-Based Integration Testing

```go
// test/vpc_test.go
package test

import (
  "testing"
  "github.com/gruntwork-io/terratest/modules/terraform"
  "github.com/gruntwork-io/terratest/modules/aws"
  "github.com/stretchr/testify/assert"
)

func TestVpcModule(t *testing.T) {
  t.Parallel()    // run multiple tests concurrently

  terraformOptions := &terraform.Options{
    TerraformDir: "../code",
    Vars: map[string]interface{}{
      "aws_region":    "us-east-1",
      "project":       "test",
      "environment":   "test",
      "vpc_cidr":      "10.99.0.0/16",    // unique CIDR for tests
      "subnet_count":  3,
    },
    EnvVars: map[string]string{
      "AWS_DEFAULT_REGION": "us-east-1",
    },
  }

  // ALWAYS defer destroy — ensures cleanup even if test panics
  defer terraform.Destroy(t, terraformOptions)

  // Deploy
  terraform.InitAndApply(t, terraformOptions)

  // Assert: VPC ID exists and has correct format
  vpcID := terraform.Output(t, terraformOptions, "vpc_id")
  assert.NotEmpty(t, vpcID)
  assert.Regexp(t, `^vpc-`, vpcID)

  // Assert: VPC CIDR matches input
  vpcCIDR := terraform.Output(t, terraformOptions, "vpc_cidr")
  assert.Equal(t, "10.99.0.0/16", vpcCIDR)

  // Assert: correct number of subnets
  subnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
  assert.Equal(t, 3, len(subnetIDs))

  // Assert: VPC actually exists in AWS (not just in state)
  vpc := aws.GetVpcById(t, vpcID, "us-east-1")
  assert.Equal(t, "available", *vpc.State)
}
```

```bash
# Run tests
cd test
go mod init test
go get github.com/gruntwork-io/terratest/modules/terraform
go get github.com/stretchr/testify/assert
go test -v -timeout 30m -run TestVpcModule ./...

# Run all tests in parallel
go test -v -timeout 60m -count=1 -parallel 10 ./...
```

---

## Test Directory Structure

```
Day20/
  code/
    provider.tf
    variables.tf
    main.tf
    outputs.tf
    terraform.tfvars
  test/
    go.mod
    go.sum
    vpc_test.go
    helpers_test.go    # shared test utilities
```

---

## GitHub Actions: Run Tests on PR

```yaml
- name: Run Terratest
  run: |
    cd test
    go test -v -timeout 30m -run TestVpcModule ./...
  env:
    AWS_DEFAULT_REGION: us-east-1
    # AWS credentials via OIDC (no static keys)
```

---

## What to Test

```go
// Test outputs exist and have correct format
assert.Regexp(t, `^vpc-`, vpcID)
assert.Regexp(t, `^subnet-`, subnetIDs[0])

// Test count matches input
assert.Equal(t, vars["subnet_count"], len(subnetIDs))

// Test CIDR matches input
assert.Equal(t, vars["vpc_cidr"], vpcCIDR)

// Test real infrastructure state via AWS SDK
vpc := aws.GetVpcById(t, vpcID, region)
assert.Equal(t, "available", *vpc.State)
assert.True(t, *vpc.EnableDnsHostnames)

// Test no resources were accidentally left from a previous failed run
// (use unique prefixes with random suffixes to prevent naming conflicts)
```
