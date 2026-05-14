# ==========================================
# 1. AUTOSCALING TARGETS (Who are we scaling?)
# ==========================================

# Telemetry Service Target
resource "aws_appautoscaling_target" "telemetry_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ev_cluster.name}/${aws_ecs_service.telemetry_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Management Service Target
resource "aws_appautoscaling_target" "management_target" {
  max_capacity       = 4
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.ev_cluster.name}/${aws_ecs_service.management_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# ==========================================
# 2. AUTOSCALING POLICIES (The Rules)
# ==========================================

# Telemetry Scale UP
resource "aws_appautoscaling_policy" "telemetry_scale_up" {
  name               = "telemetry-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.telemetry_target.resource_id
  scalable_dimension = aws_appautoscaling_target.telemetry_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.telemetry_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1 # Add 1 container
    }
  }
}

# Telemetry Scale DOWN
resource "aws_appautoscaling_policy" "telemetry_scale_down" {
  name               = "telemetry-scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.telemetry_target.resource_id
  scalable_dimension = aws_appautoscaling_target.telemetry_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.telemetry_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1 # Remove 1 container
    }
  }
}

# Management Scale UP
resource "aws_appautoscaling_policy" "management_scale_up" {
  name               = "management-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.management_target.resource_id
  scalable_dimension = aws_appautoscaling_target.management_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.management_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

# Management Scale DOWN
resource "aws_appautoscaling_policy" "management_scale_down" {
  name               = "management-scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.management_target.resource_id
  scalable_dimension = aws_appautoscaling_target.management_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.management_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# ==========================================
# 3. CLOUDWATCH ALARMS (The Triggers)
# ==========================================

# Alarm 1: Telemetry High CPU (> 80%)
resource "aws_cloudwatch_metric_alarm" "telemetry_cpu_high" {
  alarm_name          = "telemetry-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors telemetry container cpu utilization"
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ev_cluster.name
    ServiceName = aws_ecs_service.telemetry_service.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.telemetry_scale_up.arn,
    aws_sns_topic.critical_alerts.arn # Notifies you!
  ]
}

# Alarm 2: Telemetry Low CPU (< 20%)
resource "aws_cloudwatch_metric_alarm" "telemetry_cpu_low" {
  alarm_name          = "telemetry-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ev_cluster.name
    ServiceName = aws_ecs_service.telemetry_service.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.telemetry_scale_down.arn
  ]
}

# Alarm 3: Management High CPU (> 80%)
resource "aws_cloudwatch_metric_alarm" "management_cpu_high" {
  alarm_name          = "management-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ev_cluster.name
    ServiceName = aws_ecs_service.management_service.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.management_scale_up.arn,
    aws_sns_topic.critical_alerts.arn # Notifies you!
  ]
}

# Alarm 4: Management Low CPU (< 20%)
resource "aws_cloudwatch_metric_alarm" "management_cpu_low" {
  alarm_name          = "management-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = "20"
  
  dimensions = {
    ClusterName = aws_ecs_cluster.ev_cluster.name
    ServiceName = aws_ecs_service.management_service.name
  }

  alarm_actions = [
    aws_appautoscaling_policy.management_scale_down.arn
  ]
}

# 4. SNS EMAIL SUBSCRIPTION (Who gets the alerts?)
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.critical_alerts.arn
  protocol  = "email"
  endpoint  = "gaire.kabir@gmail.com"
}
