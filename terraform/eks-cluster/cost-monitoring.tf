# Cost Monitoring Alerts
resource "aws_cloudwatch_metric_alarm" "eks_control_plane_cost" {
  alarm_name          = "${var.resource_prefix}-eks-control-plane-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EKSControlPlaneMonthlyCost"
  namespace           = "AWS/CostUsage"
  period              = 86400
  statistic           = "Sum"
  threshold           = 73
  alarm_description   = "Alert when EKS control plane costs exceed $73/month"
  dimensions = {
    Service = "EKS"
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-cost-alarm" })
}

resource "aws_cloudwatch_metric_alarm" "total_monthly_cost" {
  alarm_name          = "${var.resource_prefix}-total-monthly-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/CostUsage"
  period              = 86400
  statistic           = "Maximum"
  threshold           = 50
  alarm_description   = "Alert when total monthly AWS costs exceed $50"
  dimensions = {
    Service = "ALL"
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-total-cost-alarm" })
}

resource "aws_cloudwatch_metric_alarm" "ec2_instance_cost" {
  alarm_name          = "${var.resource_prefix}-ec2-instance-cost"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EC2InstanceHours"
  namespace           = "AWS/CostUsage"
  period              = 86400
  statistic           = "Sum"
  threshold           = 48
  alarm_description   = "Alert when EC2 instance costs exceed expected usage"
  dimensions = {
    Service = "EC2"
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-ec2-cost-alarm" })
}
