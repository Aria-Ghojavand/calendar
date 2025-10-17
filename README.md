# Unicorn Service on AWS EKS

This project deploys a highly available, scalable Go web application on AWS EKS with full infrastructure automation.

## Architecture Overview

- **Compute**: AWS EKS cluster with t3.medium nodes
- **Database**: RDS PostgreSQL for persistence
- **Cache**: ElastiCache Redis for performance
- **Storage**: EFS for shared file storage
- **Config**: AWS AppConfig for centralized configuration
- **Load Balancing**: AWS Load Balancer Controller
- **Networking**: Multi-AZ VPC with public/private subnets

## Quick Start

1. **Set up AWS credentials and region**
2. **Deploy infrastructure**: `./scripts/deploy-infrastructure.sh`
3. **Deploy application**: `./scripts/deploy-application.sh`
4. **Get endpoint**: `kubectl get ingress unicorn-ingress`

## Project Structure

```
├── infrastructure/          # Terraform infrastructure code
├── kubernetes/             # Kubernetes manifests
├── scripts/               # Deployment scripts
├── config/                # Configuration files
└── docs/                  # Documentation
```

## Prerequisites

- AWS CLI configured
- kubectl installed
- Terraform installed
- Access to the provided bastion EC2 instance

## Security Considerations

- EKS API endpoint accessible from internet (for third-party security evaluation)
- IAM roles follow least privilege principle
- Database credentials auto-rotate every 30 days
- No SSH access from internet (use AWS Systems Manager)

## Monitoring

- CloudWatch for metrics and logs
- Application health check on root path (/)
- Auto-scaling based on CPU/memory usage