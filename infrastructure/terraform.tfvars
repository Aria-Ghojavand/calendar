# AWS Configuration
aws_region = "us-west-2"

# EKS Configuration
cluster_version = "1.28"
node_instance_type = "t3.medium"
node_desired_capacity = 2
node_min_capacity = 1
node_max_capacity = 10

# Database Configuration
db_instance_class = "db.t3.medium"

# Cache Configuration  
redis_node_type = "cache.t3.medium"