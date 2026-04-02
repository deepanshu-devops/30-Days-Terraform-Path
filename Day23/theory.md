# Day 23 — RDS Multi-AZ with Automatic Failover

## Real-Life Example 🏗️

**3:47 AM. PagerDuty fires.**  
The AZ where your RDS instance lives has a hardware failure. AWS declares the AZ degraded.

**Single-AZ setup:**  
Database is unreachable. On-call engineer wakes up. Restores from most recent automated backup. 4+ hours of downtime, potential data loss since last backup.

**Multi-AZ setup:**  
AWS detects the primary failure. Automatically fails over to the standby in the healthy AZ. Updates the DNS endpoint (same hostname, different IP). Your application reconnects automatically on the next connection attempt. 60-120 seconds of connectivity impact. On-call engineer sleeps through it.

**Cost of Multi-AZ:** ~2× single-AZ instance price.  
**Cost of 4 hours of database downtime:** Much, much more.

---

## How Multi-AZ Works

```
us-east-1a                              us-east-1b
    │                                       │
[Primary RDS]  ←──── synchronous ────►  [Standby RDS]
    │                 replication               │
  Writes                                 (identical data)
    │                                       │
[DNS endpoint: myapp.xxxx.rds.amazonaws.com]
        │
        └── Always points to the primary
            AWS auto-updates DNS in 60-120s on failover
            Application: same connection string, auto-reconnects
```

The application connects using the same DNS hostname before and after failover. No code changes. No manual intervention. Automatic.

---

## What Multi-AZ Protects Against

| Failure Type | Single-AZ | Multi-AZ |
|-------------|-----------|---------|
| AZ hardware failure | ❌ Outage | ✅ Automatic failover |
| Instance failure | ❌ Outage | ✅ Automatic failover |
| Host OS patching | ❌ Reboot required | ✅ Failover, no downtime |
| Data corruption | ❌ Restore from backup | ❌ Both AZs get the corruption |

For data corruption protection: enable automated backups + point-in-time recovery.

---

## Complete Production RDS Configuration

```hcl
resource "aws_db_instance" "main" {
  identifier        = "${var.project}-${var.environment}"
  engine            = "postgres"
  engine_version    = "15.4"

  # Sizing (scale up for prod)
  instance_class         = "db.r6g.large"    # memory-optimised for DB workloads
  allocated_storage      = 100
  max_allocated_storage  = 1000              # autoscale up to 1TB

  # Security
  storage_encrypted      = true
  kms_key_id             = aws_kms_key.rds.arn
  publicly_accessible    = false             # NEVER true in production
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  # High Availability
  multi_az               = true              # standby in second AZ

  # Credentials via Secrets Manager (never hardcoded)
  username = var.db_username
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # Backup
  backup_retention_period   = 7             # 7 days of automated backups
  backup_window             = "03:00-04:00" # low-traffic window
  maintenance_window        = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot     = true

  # Safety
  deletion_protection       = true          # must set to false before terraform destroy
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project}-${var.environment}-final"

  # Observability
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60      # enhanced monitoring every 60s

  tags = { Name = "${var.project}-${var.environment}" }
}
```

---

## RDS Proxy — Connection Pooling (Production Necessity)

At scale, applications open many database connections. RDS has connection limits based on instance size. RDS Proxy pools connections and speeds up failover.

```hcl
resource "aws_db_proxy" "main" {
  name                   = "${var.project}-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy.id]
  vpc_subnet_ids         = aws_subnet.private[*].id

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "REQUIRED"
    secret_arn  = aws_secretsmanager_secret.db_password.arn
  }
}
```

Benefits: 
- Connection pooling → handles 10× more connections per instance
- Failover in ~5s (vs 60s direct) because proxy maintains connections
- IAM authentication for database access
