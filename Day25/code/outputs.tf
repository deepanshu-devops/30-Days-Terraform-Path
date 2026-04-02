output "vpc_id" { value = aws_vpc.main.id }
output "sg_id" { value = aws_security_group.web.id }
output "alert_topic_arn" { value = aws_sns_topic.drift_alerts.arn }
