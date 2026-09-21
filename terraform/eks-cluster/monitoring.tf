# CloudWatch Monitoring for EKS Cluster

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "eks_dashboard" {
  dashboard_name = "${var.resource_prefix}-eks-monitoring"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EKS", "ControlPlaneVersion", "ClusterName", var.cluster_name, { stat = "Average" }],
            ["AWS/EKS", "ControlPlaneCPUUtilization", "ClusterName", var.cluster_name, { stat = "Average" }],
            ["AWS/EKS", "ControlPlaneMemoryUtilization", "ClusterName", var.cluster_name, { stat = "Average" }],
            ["AWS/EKS", "RunningPodCount", "ClusterName", var.cluster_name, { stat = "Average" }],
            ["AWS/EKS", "RunningNodeCount", "ClusterName", var.cluster_name, { stat = "Average" }],
            ["AWS/EKS", "ActiveManagementServiceCount", "ClusterName", var.cluster_name, { stat = "Average" }],
            ["AWS/EKS", "FailedManagementServiceCount", "ClusterName", var.cluster_name, { stat = "Average" }],
          ]
          view      = "timeSeries"
          stacked   = false
          region    = var.region
          title     = "EKS Control Plane Metrics"
          period    = 300
          stat      = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", "i-0123456789abcdef0", { stat = "Average", label = "Node CPU" }],
            ["AWS/EC2", "NetworkIn", "InstanceId", "i-0123456789abcdef0", { stat = "Average", label = "Network In" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", "i-0123456789abcdef0", { stat = "Average", label = "Network Out" }],
            ["AWS/EC2", "DiskReadBytes", "InstanceId", "i-0123456789abcdef0", { stat = "Average", label = "Disk Read" }],
            ["AWS/EC2", "DiskWriteBytes", "InstanceId", "i-0123456789abcdef0", { stat = "Average", label = "Disk Write" }],
          ]
          view      = "timeSeries"
          stacked   = false
          region    = var.region
          title     = "EKS Node Group Metrics (placeholder - update with actual instance IDs)"
          period    = 300
          stat      = "Average"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EBS", "VolumeReadBytes", "VolumeId", "vol-0123456789abcdef0", { stat = "Average", label = "EBS Read" }],
            ["AWS/EBS", "VolumeWriteBytes", "VolumeId", "vol-0123456789abcdef0", { stat = "Average", label = "EBS Write" }],
            ["AWS/EBS", "VolumeReadOps", "VolumeId", "vol-0123456789abcdef0", { stat = "Average", label = "EBS Read Ops" }],
            ["AWS/EBS", "VolumeWriteOps", "VolumeId", "vol-0123456789abcdef0", { stat = "Average", label = "EBS Write Ops" }],
          ]
          view      = "timeSeries"
          stacked   = false
          region    = var.region
          title     = "EBS Volume Metrics (placeholder - update with actual volume IDs)"
          period    = 300
          stat      = "Average"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/eks-alb/1234567890abcdef", { stat = "Sum", label = "Requests" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/eks-alb/1234567890abcdef", { stat = "Average", label = "Response Time" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", "app/eks-alb/1234567890abcdef", { stat = "Average", label = "Unhealthy Hosts" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", "app/eks-alb/1234567890abcdef", { stat = "Average", label = "Healthy Hosts" }],
          ]
          view      = "timeSeries"
          stacked   = false
          region    = var.region
          title     = "Application Load Balancer Metrics (placeholder - update with actual ALB ARN)"
          period    = 300
          stat      = "Average"
        }
      },
    ]
  })
}

# CloudWatch Log Group for EKS Cluster Logs
resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-eks-cluster-logs"
  })
}

# CloudWatch Log Group for EKS Node Logs
resource "aws_cloudwatch_log_group" "eks_node_logs" {
  name              = "/aws/eks/${var.cluster_name}/node"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-eks-node-logs"
  })
}

# CloudWatch Metric Alarm - EKS Control Plane CPU
resource "aws_cloudwatch_metric_alarm" "eks_control_plane_cpu" {
  alarm_name          = "${var.resource_prefix}-eks-control-plane-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ControlPlaneCPUUtilization"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alert when EKS control plane CPU exceeds 70%"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-cp-cpu" })
}

# CloudWatch Metric Alarm - EKS Control Plane Memory
resource "aws_cloudwatch_metric_alarm" "eks_control_plane_memory" {
  alarm_name          = "${var.resource_prefix}-eks-control-plane-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ControlPlaneMemoryUtilization"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alert when EKS control plane memory exceeds 70%"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-cp-memory" })
}

# CloudWatch Metric Alarm - Running Nodes Low
resource "aws_cloudwatch_metric_alarm" "eks_running_nodes_low" {
  alarm_name          = "${var.resource_prefix}-eks-running-nodes-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningNodeCount"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = var.node_group_min_size
  alarm_description   = "Alert when EKS node group has fewer nodes than minimum"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-nodes-low" })
}

# CloudWatch Metric Alarm - Failed Management Services
resource "aws_cloudwatch_metric_alarm" "eks_failed_management_services" {
  alarm_name          = "${var.resource_prefix}-eks-failed-management-services"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FailedManagementServiceCount"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alert when EKS management services are failed"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-failed-services" })
}

# CloudWatch Metric Alarm - Pod Count High
resource "aws_cloudwatch_metric_alarm" "eks_pod_count_high" {
  alarm_name          = "${var.resource_prefix}-eks-pod-count-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "RunningPodCount"
  namespace           = "AWS/EKS"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  alarm_description   = "Alert when EKS pod count exceeds 100"
  dimensions = {
    ClusterName = var.cluster_name
  }
  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-pod-high" })
}

# SNS Topic for Alerts
resource "aws_sns_topic" "eks_alerts" {
  name = "${var.resource_prefix}-eks-alerts"

  tags = merge(var.tags, { Name = "${var.resource_prefix}-eks-alerts-topic" })
}

# SNS Topic Policy for CloudWatch Alarms
resource "aws_sns_topic_policy" "eks_alerts_policy" {
  arn = aws_sns_topic.eks_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        },
        Action   = "sns:Publish",
        Resource = aws_sns_topic.eks_alerts.arn
      }
    ]
  })
}

# SNS Topic Subscription (email)
resource "aws_sns_topic_subscription" "eks_alerts_email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.eks_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Metric Filter for EKS Control Plane Logs
resource "aws_cloudwatch_log_metric_filter" "eks_control_plane_errors" {
  name           = "${var.resource_prefix}-eks-control-plane-errors"
  pattern        = "\"ERROR\" OR \"Exception\" OR \"Fail\""
  log_group_name = aws_cloudwatch_log_group.eks_cluster_logs.name

  metric_transformation {
    name      = "${var.resource_prefix}-eks-control-plane-error-count"
    namespace = "${var.resource_prefix}/EKS"
    value     = "1"
    dimensions = {
      ClusterName = var.cluster_name
    }
  }
}

# CloudWatch Log Metric Filter for Node Logs
resource "aws_cloudwatch_log_metric_filter" "eks_node_errors" {
  name           = "${var.resource_prefix}-eks-node-errors"
  pattern        = "\"ERROR\" OR \"Exception\" OR \"Fail\""
  log_group_name = aws_cloudwatch_log_group.eks_node_logs.name

  metric_transformation {
    name      = "${var.resource_prefix}-eks-node-error-count"
    namespace = "${var.resource_prefix}/EKS"
    value     = "1"
    dimensions = {
      ClusterName = var.cluster_name
    }
  }
}