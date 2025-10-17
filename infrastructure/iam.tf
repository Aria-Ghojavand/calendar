# Service Account for AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach the ELB Controller Policy
data "aws_iam_policy" "elb_controller" {
  name = "ELBControllerPolicy"
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = data.aws_iam_policy.elb_controller.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}

# Service Account for EFS CSI Driver
resource "aws_iam_role" "efs_csi_driver" {
  name = "efs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:efs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach the EFS Policy
data "aws_iam_policy" "efs_policy" {
  name = "EFSPolicy"
}

resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = data.aws_iam_policy.efs_policy.arn
  role       = aws_iam_role.efs_csi_driver.name
}

# Service Account for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach the AutoScaler Policy
data "aws_iam_policy" "autoscaler_policy" {
  name = "AutoScalerPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = data.aws_iam_policy.autoscaler_policy.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

# Service Account for Unicorn Application
resource "aws_iam_role" "unicorn_app" {
  name = "unicorn-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.cluster.arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:default:unicorn-service"
            "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for Unicorn Application
resource "aws_iam_policy" "unicorn_app" {
  name        = "unicorn-app-policy"
  description = "Policy for Unicorn application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appconfig:GetConfiguration",
          "appconfig:StartConfigurationSession"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "unicorn_app" {
  policy_arn = aws_iam_policy.unicorn_app.arn
  role       = aws_iam_role.unicorn_app.name
}

# Attach the Unicorn Policy
data "aws_iam_policy" "unicorn_policy" {
  name = "UnicornPolicy"
}

resource "aws_iam_role_policy_attachment" "unicorn_policy" {
  policy_arn = data.aws_iam_policy.unicorn_policy.arn
  role       = aws_iam_role.unicorn_app.name
}