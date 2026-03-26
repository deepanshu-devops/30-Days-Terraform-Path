# Day 20 — Terratest Example
# File: test/vpc_test.go

# To run this, you need Go installed:
# go mod init test
# go get github.com/gruntwork-io/terratest/modules/terraform
# go get github.com/stretchr/testify/assert
# go test -v -timeout 30m ./...

# See theory.md for the full Go test code.
# Below is the Makefile for the test workflow:

# Makefile
# test:
#   cd test && go test -v -timeout 30m -run TestVpcModule ./...
#
# test-short:
#   terraform validate && terraform plan
#
# security-scan:
#   checkov -d . --framework terraform
#   tfsec . --minimum-severity HIGH
#
# docs:
#   terraform-docs markdown . > README.md

# ── Terraform config being tested ─────────────────────────────────────────
# modules/vpc/main.tf (the testable module) is in Day10/code/modules/vpc
# The test in theory.md deploys it and validates the outputs
