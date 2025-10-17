# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "unicorn-cache-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = local.common_tags
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "main" {
  family = "redis7.x"
  name   = "unicorn-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = local.common_tags
}

# ElastiCache Replication Group (Redis)
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "unicorn-redis"
  description                = "Redis cluster for Unicorn service"
  
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.main.name
  node_type                  = var.redis_node_type
  
  num_cache_clusters         = 2
  
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.elasticache.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  maintenance_window = "sun:03:00-sun:04:00"
  snapshot_retention_limit = 5
  snapshot_window = "02:00-03:00"
  
  tags = merge(local.common_tags, {
    Name = "unicorn-redis"
  })
}