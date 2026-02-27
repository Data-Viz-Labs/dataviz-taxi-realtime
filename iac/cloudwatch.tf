# CloudWatch Log Metric Filters for Group Tracking
resource "aws_cloudwatch_log_metric_filter" "auth_success_by_group" {
  name           = "${local.name_prefix}-auth-success-by-group"
  log_group_name = aws_cloudwatch_log_group.ecs.name
  pattern        = "[time, dash, name, dash2, level=INFO, dash3, msg=\"AUTH_SUCCESS*\"]"

  metric_transformation {
    name      = "AuthSuccessByGroup"
    namespace = local.name_prefix
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "auth_failed" {
  name           = "${local.name_prefix}-auth-failed"
  log_group_name = aws_cloudwatch_log_group.ecs.name
  pattern        = "[time, dash, name, dash2, level=WARNING, dash3, msg=\"AUTH_FAILED*\"]"

  metric_transformation {
    name      = "AuthFailed"
    namespace = local.name_prefix
    value     = "1"
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name_prefix

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", aws_ecs_service.normal.name, "ClusterName", aws_ecs_cluster.main.name, { stat = "Average", label = "Normal CPU" }],
            ["...", aws_ecs_service.spot.name, ".", ".", { stat = "Average", label = "Spot CPU" }],
            [".", "MemoryUtilization", ".", aws_ecs_service.normal.name, ".", ".", { stat = "Average", label = "Normal Memory" }],
            ["...", aws_ecs_service.spot.name, ".", ".", { stat = "Average", label = "Spot Memory" }]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Resource Utilisation"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
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
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Average", label = "Healthy Targets" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average", label = "Unhealthy Targets" }]
          ]
          period = 60
          stat   = "Average"
          region = var.aws_region
          title  = "ECS Task Count (Healthy Targets)"
          yAxis = {
            left = {
              min = 0
            }
          }
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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Average", label = "Average" }],
            ["...", { stat = "p95", label = "p95" }],
            ["...", { stat = "p99", label = "p99" }]
          ]
          period = 300
          region = var.aws_region
          title  = "API Latency"
          yAxis = {
            left = {
              min = 0
            }
          }
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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum", label = "Total Requests" }],
            [".", "HTTPCode_Target_2XX_Count", ".", ".", { stat = "Sum", label = "2xx Success" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum", label = "4xx Client Error" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum", label = "5xx Server Error" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Request Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Sum" }],
            [".", "TargetConnectionErrorCount", ".", ".", { stat = "Sum" }],
            [".", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app.arn_suffix, "LoadBalancer", aws_lb.app.arn_suffix, { stat = "Average" }],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Average" }]
          ]
          period = 300
          region = var.aws_region
          title  = "Connection & Health Metrics"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.ecs.name}' | fields @timestamp, @message | filter @message like \"AUTH_SUCCESS\" | parse @message \"group=*\" as group | stats count() by group"
          region  = var.aws_region
          title   = "Requests by Group (Last Hour)"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["${local.name_prefix}", "AuthFailed", { stat = "Sum", label = "Auth Failures" }]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "Authentication Failures"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          query   = "SOURCE '${aws_cloudwatch_log_group.ecs.name}' | fields @timestamp, @message | filter @message like \"AUTH_FAILED\" | parse @message \"reason=* |\" as reason | stats count() by reason"
          region  = var.aws_region
          title   = "Auth Failure Reasons"
        }
      }
    ]
  })
}
