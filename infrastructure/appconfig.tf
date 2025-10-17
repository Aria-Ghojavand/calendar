# AWS App Config Application
resource "aws_appconfig_application" "unicorn" {
  name        = "unicorn-service"
  description = "Configuration for Unicorn Service"

  tags = local.common_tags
}

# AWS App Config Environment
resource "aws_appconfig_environment" "production" {
  name           = "production"
  description    = "Production environment"
  application_id = aws_appconfig_application.unicorn.id

  monitor {
    alarm_arn      = aws_cloudwatch_metric_alarm.app_errors.arn
    alarm_role_arn = aws_iam_role.appconfig_monitor.arn
  }

  tags = local.common_tags
}

# AWS App Config Configuration Profile
resource "aws_appconfig_configuration_profile" "unicorn" {
  application_id = aws_appconfig_application.unicorn.id
  name           = "unicorn-config"
  description    = "Main configuration for Unicorn service"
  location_uri   = "hosted"
  type           = "AWS.Freeform"

  tags = local.common_tags
}

# AWS App Config Hosted Configuration Version
resource "aws_appconfig_hosted_configuration_version" "unicorn" {
  application_id          = aws_appconfig_application.unicorn.id
  configuration_profile_id = aws_appconfig_configuration_profile.unicorn.configuration_profile_id
  description             = "Initial configuration"
  content_type            = "application/json"

  content = jsonencode({
    database = {
      host     = aws_db_instance.main.endpoint
      port     = aws_db_instance.main.port
      name     = "unicorndb"
      user     = "unicorn"
      sslMode  = "require"
    }
    redis = {
      host = aws_elasticache_replication_group.main.primary_endpoint_address
      port = 6379
    }
    server = {
      port = 80
      host = "0.0.0.0"
    }
    efs = {
      fsPath = "/app-cache/"
    }
    logging = {
      level = "info"
    }
  })
}

# AWS App Config Deployment Strategy
resource "aws_appconfig_deployment_strategy" "unicorn" {
  name                           = "unicorn-deployment"
  description                    = "Deployment strategy for Unicorn service"
  deployment_duration_in_minutes = 5
  final_bake_time_in_minutes     = 5
  growth_factor                  = 100
  growth_type                    = "LINEAR"
  replicate_to                   = "NONE"

  tags = local.common_tags
}

# CloudWatch Alarm for App Config monitoring
resource "aws_cloudwatch_metric_alarm" "app_errors" {
  alarm_name          = "unicorn-app-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ErrorRate"
  namespace           = "Unicorn/Application"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "This metric monitors application error rate"
  alarm_actions       = []

  tags = local.common_tags
}

# IAM Role for App Config monitoring
resource "aws_iam_role" "appconfig_monitor" {
  name = "unicorn-appconfig-monitor"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appconfig.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "appconfig_monitor" {
  name = "appconfig-monitor-policy"
  role = aws_iam_role.appconfig_monitor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      }
    ]
  })
}