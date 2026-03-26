# Day 11 — Module Versioning Best Practices

## WHAT
Module versioning ensures changes to shared modules don't unexpectedly break environments that depend on them.

## Version Sources

### Git Tags (Most Common)
```hcl
module "vpc" {
  source = "git::https://github.com/org/terraform-modules.git//vpc?ref=v1.2.0"
}
```

### Terraform Registry
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}
```

### Local Paths (Development Only)
```hcl
module "vpc" {
  source = "../../modules/vpc"  # Never in production
}
```

## Semantic Versioning

```
MAJOR.MINOR.PATCH
v1.2.3
│  │  └── Patch: bug fixes, no API changes
│  └───── Minor: new features, backward compatible
└──────── Major: breaking changes (variable renamed, resource type changed)
```

## Release Workflow

```bash
# 1. Make changes to module
git add modules/vpc/
git commit -m "feat(vpc): add flow logs support"

# 2. Tag the release
git tag v1.3.0
git push origin v1.3.0

# 3. Update CHANGELOG
echo "## v1.3.0 - Add VPC flow logs support" >> CHANGELOG.md

# 4. Test in dev environment first
# modules/vpc/dev test: version = "v1.3.0"

# 5. Roll out to staging, then production
```

## Version Constraint Operators

```hcl
version = "= 1.2.0"   # Exactly this version (strict)
version = ">= 1.2.0"  # At least 1.2.0
version = "~> 1.2"    # >= 1.2, < 2.0 (recommended for modules)
version = "~> 1.2.0"  # >= 1.2.0, < 1.3.0 (stricter)
```

## Audience Levels

### 🟢 Beginner
Use version tags. Without them, a teammate can break your production by updating a shared module. With `?ref=v1.2.0`, you control when you upgrade.

### 🔵 Intermediate
Keep a `CHANGELOG.md` in every module repo. When you tag a new version, document: what changed, what broke, how to migrate.

### 🟠 Advanced
Build a module registry CI pipeline: auto-run Terratest on every PR, enforce semver tags, auto-generate docs with `terraform-docs`.

### 🔴 Expert
Treat modules as versioned APIs. Deprecation policy: major versions supported for 12 months minimum. Provide migration guides for breaking changes. Build a compatibility matrix across Terraform versions.
