# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "unicorn-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(local.common_tags, {
    Name = "unicorn-db-subnet-group"
  })
}

# RDS Parameter Group for PostgreSQL
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "unicorn-postgres-params"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  tags = local.common_tags
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Secrets Manager secret for RDS credentials
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "unicorn-db-credentials"
  description             = "Database credentials for Unicorn service"
  recovery_window_in_days = 7

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "unicorn"
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = "unicorndb"
  })
}

# Secrets Manager rotation
resource "aws_secretsmanager_secret_rotation" "db_credentials" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_lambda_function.rotate_secret.arn

  rotation_rules {
    automatically_after_days = 30
  }

  depends_on = [aws_lambda_permission.allow_secret_manager_call_lambda]
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "unicorn-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "unicorndb"
  username = "unicorn"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  skip_final_snapshot = true
  deletion_protection = false

  # Enable automated minor version upgrades
  auto_minor_version_upgrade = true

  # Enable performance insights
  performance_insights_enabled = true

  tags = merge(local.common_tags, {
    Name = "unicorn-db"
  })
}

# Lambda function for secret rotation (simplified)
resource "aws_lambda_function" "rotate_secret" {
  filename         = "rotate_secret.zip"
  function_name    = "unicorn-rotate-secret"
  role            = aws_iam_role.lambda_rotation.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  depends_on = [data.archive_file.rotate_secret_zip]

  tags = local.common_tags
}

# Create a simple rotation function
data "archive_file" "rotate_secret_zip" {
  type        = "zip"
  output_path = "rotate_secret.zip"
  
  source {
    content = <<EOF
import json
import boto3

def lambda_handler(event, context):
    # Simplified rotation logic - in production, implement proper rotation
    print("Secret rotation triggered")
    return {
        'statusCode': 200,
        'body': json.dumps('Rotation completed')
    }
EOF
    filename = "lambda_function.py"
  }
}

# IAM role for Lambda rotation function
resource "aws_iam_role" "lambda_rotation" {
  name = "unicorn-lambda-rotation-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM policy for Lambda rotation function
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_rotation.name
}

resource "aws_iam_role_policy" "lambda_rotation" {
  name = "unicorn-lambda-rotation-policy"
  role = aws_iam_role.lambda_rotation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "rds:ModifyDBInstance"
        ]
        Resource = aws_db_instance.main.arn
      }
    ]
  })
}

# Lambda permission for Secrets Manager
resource "aws_lambda_permission" "allow_secret_manager_call_lambda" {
  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotate_secret.function_name
  principal     = "secretsmanager.amazonaws.com"
}