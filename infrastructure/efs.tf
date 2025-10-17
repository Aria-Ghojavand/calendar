# EFS File System
resource "aws_efs_file_system" "main" {
  creation_token = "unicorn-efs"
  
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100
  
  encrypted = true
  
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  
  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(local.common_tags, {
    Name = "unicorn-efs"
  })
}

# EFS Mount Targets
resource "aws_efs_mount_target" "main" {
  count = length(aws_subnet.private)
  
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

# EFS Access Point for application
resource "aws_efs_access_point" "app" {
  file_system_id = aws_efs_file_system.main.id
  
  posix_user {
    gid = 1000
    uid = 1000
  }
  
  root_directory {
    path = "/app-cache"
    
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }

  tags = merge(local.common_tags, {
    Name = "unicorn-efs-access-point"
  })
}