# Day 13 — count, for_each & Dynamic Blocks

## Real-Life Example 🏗️

**The Subnet Removal Problem:**  
You use `count = 4` to create 4 subnets indexed 0–3.  
Six months later, the network team removes subnet at index 0 (10.0.0.0/24) because it conflicts with a new VPN range.

You update the list. Terraform computes the new indices: what was index 1 becomes index 0, index 2 becomes index 1, etc.  
Result: Terraform wants to **destroy and recreate all 3 remaining subnets** — because their indices changed.  
Destroying subnets that have EC2 instances causes those instances to lose their network.

**With `for_each` using a map with string keys:**  
Each subnet has a stable name like `"app-east-1a"`. Removing `"app-east-1a"` destroys only that one subnet. The others are completely unaffected.

---

## `count` — Numbered Copies

```hcl
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = { Name = "subnet-${count.index + 1}" }
}

# Reference individual subnets:
aws_subnet.public[0].id     # first subnet
aws_subnet.public[1].id     # second subnet
aws_subnet.public[*].id     # all subnet IDs as a list
```

**Problems with count:**
- Removing item at index 0 shifts all higher indices → destroys and recreates them
- Can't use computed values in `count` that aren't known until apply
- No stable addressing — `public[0]` might mean something different after a list change

---

## `for_each` — Stable Key-Based Copies

```hcl
variable "subnets" {
  type = map(object({
    cidr              = string
    availability_zone = string
    tier              = string
  }))
  default = {
    "web-east-1a"    = { cidr = "10.0.1.0/24",  availability_zone = "us-east-1a", tier = "public"  }
    "web-east-1b"    = { cidr = "10.0.2.0/24",  availability_zone = "us-east-1b", tier = "public"  }
    "app-east-1a"    = { cidr = "10.0.11.0/24", availability_zone = "us-east-1a", tier = "private" }
    "app-east-1b"    = { cidr = "10.0.12.0/24", availability_zone = "us-east-1b", tier = "private" }
  }
}

resource "aws_subnet" "main" {
  for_each          = var.subnets              # Each map key = one subnet
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.availability_zone

  tags = {
    Name = each.key                            # "web-east-1a", "app-east-1b", etc.
    Tier = each.value.tier
  }
}

# Reference individual subnets:
aws_subnet.main["web-east-1a"].id             # stable, by name
aws_subnet.main["app-east-1b"].id

# All subnet IDs as a list:
values(aws_subnet.main)[*].id

# Only public subnets:
[for k, v in aws_subnet.main : v.id if v.tags["Tier"] == "public"]
```

---

## `for_each` on a Set of Strings

```hcl
resource "aws_s3_bucket" "logs" {
  for_each = toset(["access-logs", "alb-logs", "cloudtrail"])

  bucket        = "${var.project}-${each.key}"
  force_destroy = true

  tags = { Name = "${var.project}-${each.key}", Type = each.key }
}

# Creates:
# aws_s3_bucket.logs["access-logs"]
# aws_s3_bucket.logs["alb-logs"]
# aws_s3_bucket.logs["cloudtrail"]
```

---

## `dynamic` Blocks — Variable Nested Blocks

Use when a resource has a nested block that may appear 0, 1, or N times based on a variable.

```hcl
variable "ingress_rules" {
  type = list(object({
    port        = number
    protocol    = string
    cidr        = string
    description = string
  }))
  default = [
    { port = 443, protocol = "tcp", cidr = "0.0.0.0/0", description = "HTTPS" },
    { port = 80,  protocol = "tcp", cidr = "0.0.0.0/0", description = "HTTP redirect" },
    { port = 8080,protocol = "tcp", cidr = "10.0.0.0/8", description = "Internal API" }
  ]
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules         # iterator name = "ingress" by default
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [ingress.value.cidr]
      description = ingress.value.description
    }
  }

  egress {
    from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Without `dynamic`: you'd need 3 hardcoded `ingress {}` blocks. Adding a rule = editing the resource. With `dynamic`: add to the variable, get a new rule automatically.

---

## count vs for_each — Decision Guide

```
Question: Will you ever remove a specific item from the middle of the list?
├── No, it's always all-or-nothing → count is fine
└── Yes, or maybe → use for_each

Question: Does each resource have different configuration?
├── No, they're identical except for index → count
└── Yes → for_each

Question: Can the value be expressed as a stable string key?
├── Yes (name, region, tier) → for_each
└── No, it's just a number → count
```

**In practice:** Use `for_each` by default. Use `count` only for simple `count = var.enabled ? 1 : 0` patterns (create-or-not).
