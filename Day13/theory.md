# Day 13 — count, for_each & Dynamic Blocks

## WHAT
Meta-arguments for creating multiple instances of a resource.

## count
```hcl
resource "aws_subnet" "public" {
  count      = 3
  cidr_block = cidrsubnet("10.0.0.0/16", 8, count.index + 1)
  vpc_id     = aws_vpc.main.id
  tags       = { Name = "subnet-${count.index + 1}" }
}

# Reference: aws_subnet.public[0].id, aws_subnet.public[1].id, etc.
# All IDs:   aws_subnet.public[*].id
```

**Problem with count:** If you remove item 0, all subsequent resources are destroyed and recreated (indices shift).

## for_each
```hcl
variable "subnets" {
  type = map(object({
    cidr = string
    az   = string
    tier = string
  }))
  default = {
    "public-1a"  = { cidr = "10.0.1.0/24",  az = "us-east-1a", tier = "public" }
    "public-1b"  = { cidr = "10.0.2.0/24",  az = "us-east-1b", tier = "public" }
    "private-1a" = { cidr = "10.0.11.0/24", az = "us-east-1a", tier = "private" }
    "private-1b" = { cidr = "10.0.12.0/24", az = "us-east-1b", tier = "private" }
  }
}

resource "aws_subnet" "main" {
  for_each = var.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az
  tags = {
    Name = each.key
    Tier = each.value.tier
  }
}

# Reference: aws_subnet.main["public-1a"].id
# All IDs:   values(aws_subnet.main)[*].id
```

**Advantage:** Removing "public-1a" only destroys that one subnet, not all of them.

## Dynamic Blocks

```hcl
variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTPS" },
    { from_port = 80,  to_port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "HTTP" }
  ]
}

resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

## count vs for_each Decision

| Use count when | Use for_each when |
|---|---|
| All instances are identical | Each instance is different |
| Number is computed | Keys uniquely identify instances |
| Simple lists | Maps or sets |
| Don't need to reference by name | Need stable resource addressing |

## Audience Levels

### 🟢 Beginner
`count = 3` creates 3 copies. `for_each = {a = ..., b = ...}` creates one per key. Use `count` for simple cases, `for_each` when each resource has different config.

### 🔵 Intermediate
Prefer `for_each` over `count` for almost everything. With `count`, if you add an item at the beginning of the list, all resources are destroyed and recreated. With `for_each`, only new resources are created.

### 🟠 Advanced
`for_each` cannot use values known only after apply. If your set/map contains values computed by another resource, you'll get: "The "for_each" set includes values derived from resource attributes that cannot be determined until apply."

### 🔴 Expert
Use `toset()` to convert a list to a set for `for_each`. Sets deduplicate. Maps preserve order. Nested `for_each` is possible via `flatten()` + `for` expressions. Be careful with `count` in modules — changing `count` inside a module can cause unexpected destroys of all module resources.
