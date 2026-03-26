# Day 23 — RDS Multi-AZ with Automatic Failover

## WHAT
Multi-AZ RDS deploys a primary instance and a synchronous standby replica in a different Availability Zone. AWS automatically fails over to the standby if the primary fails.

## Architecture

```
us-east-1a              us-east-1b
    │                       │
[Primary RDS]  ←sync→  [Standby RDS]
    │                       │
  App                   App (after failover)
    │                       │
[DNS endpoint: mydb.xxxx.us-east-1.rds.amazonaws.com]
                ↓
       (DNS cutover in ~60s on failover)
```

## Production RDS Configuration

```hcl
resource "aws_db_instance" "main" {
  identifier        = "${var.project}-${var.environment}"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = "db.r6g.large"
  allocated_storage = 100
  max_allocated_storage = 1000   # Enable autoscaling up to 1TB

  # Security — encryption
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  # HA — Multi-AZ
  multi_az = true

  # Networking — private only
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Backup
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"
  copy_tags_to_snapshot   = true
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.project}-${var.environment}-final"

  # Performance
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.rds_monitoring.arn

  # Credentials from Secrets Manager
  username = var.db_username
  password = data.aws_secretsmanager_secret_version.db_password.secret_string

  # Parameter group for tuning
  parameter_group_name = aws_db_parameter_group.postgres15.name

  tags = local.common_tags
}
```

## CloudWatch Alarms for RDS

```hcl
resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_storage" {
  alarm_name          = "${var.project}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 10737418240  # 10 GB in bytes
  alarm_actions       = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.identifier }
}
```

---

## Audience Levels

### 🟢 Beginner
`multi_az = true` = AWS creates a hot standby. If your database dies, AWS automatically switches to the backup in ~60 seconds. Your app doesn't need to do anything — same DNS endpoint.

### 🔵 Intermediate
Multi-AZ protects against AZ failure, hardware failure, patching. It does NOT protect against data corruption (both AZs have the same data). For protection against corruption: enable automated backups + point-in-time recovery.

### 🟠 Advanced
For read scaling, add Read Replicas (`aws_db_instance` with `replicate_source_db`). For global distribution, use Aurora Global Database. For high IOPS, use `gp3` storage and tune `iops` separately.

### 🔴 Expert
RDS Proxy sits between app and RDS — pools connections (reduces RDS connection overhead), speeds up failover (app connects to proxy, which reconnects to new primary), works with Secrets Manager for IAM auth. At 200K sessions: RDS Proxy is non-negotiable.
