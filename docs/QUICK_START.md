# Quick Start Guide

## Overview
This repository contains the complete infrastructure and deployment automation for the Unicorn Service GameDay challenge. The solution deploys a highly available, scalable Go application on AWS EKS.

## Prerequisites

1. **AWS Account Access** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **kubectl** installed and working
4. **Terraform** installed (>= 1.0)
5. **Docker** installed and running
6. **Unicorn Service Binary** (download from game event)

## Quick Deployment (2-Hour Window)

### Step 1: Get the Binary (5 minutes)
```bash
# Download the unicorn-service binary from the game event README
# Place it in the docker/ directory
curl -o docker/unicorn-service https://your-game-event-url/unicorn-service
chmod +x docker/unicorn-service
```

### Step 2: Deploy Infrastructure (60-90 minutes)
```bash
# This will create VPC, EKS, RDS, ElastiCache, EFS, ECR, AppConfig
./scripts/deploy-infrastructure.sh
```

This script will:
- ✅ Create VPC with public/private subnets across 2 AZs
- ✅ Deploy EKS cluster with managed node groups (t3.medium)
- ✅ Set up RDS PostgreSQL with auto-rotation secrets
- ✅ Create ElastiCache Redis cluster
- ✅ Configure EFS for shared storage
- ✅ Set up ECR repository
- ✅ Configure AWS AppConfig
- ✅ Build and push Docker image
- ✅ Install required EKS add-ons

### Step 3: Deploy Application (15-30 minutes)
```bash
# This will deploy the app to EKS with auto-scaling
./scripts/deploy-application.sh
```

This script will:
- ✅ Deploy the application with 2 initial replicas
- ✅ Configure horizontal pod autoscaling (2-20 pods)
- ✅ Set up Application Load Balancer
- ✅ Configure health checks
- ✅ Mount EFS for caching

### Step 4: Get Endpoint & Submit (2 minutes)
```bash
# Check status and get the public endpoint
./scripts/check-status.sh

# Get the load balancer URL
kubectl get ingress unicorn-ingress -n unicorn-app
```

Submit the HTTP endpoint to the GameDay Dashboard!

## Monitoring & Troubleshooting

### Check Status
```bash
./scripts/check-status.sh status  # Quick status check
./scripts/check-status.sh full    # Comprehensive status
./scripts/check-status.sh logs    # View application logs
```

### Scale Application
```bash
# Manual scaling
kubectl scale deployment unicorn-app --replicas=5 -n unicorn-app

# Check auto-scaling
kubectl get hpa -n unicorn-app
```

### Performance Testing
```bash
# Install hey tool
go install github.com/rakyll/hey@latest

# Load test (replace with your endpoint)
hey -n 1000 -c 10 http://your-alb-endpoint.elb.amazonaws.com/
```

## Architecture Highlights

- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Auto Scaling**: HPA scales from 2-20 pods based on CPU/memory
- **Caching**: ElastiCache Redis + EFS shared storage for efficiency
- **Security**: IAM roles with least privilege, encrypted storage
- **Monitoring**: CloudWatch integration, health checks
- **Database**: RDS PostgreSQL with automated credential rotation

## Key Files

- `infrastructure/` - Terraform infrastructure as code
- `kubernetes/` - K8s manifests for application deployment  
- `scripts/` - Automated deployment and management scripts
- `docker/` - Dockerfile and binary location

## Troubleshooting

### Common Issues

1. **Binary not found**: Make sure to download and place the unicorn-service binary in `docker/`
2. **AWS permissions**: Ensure your AWS user has the required IAM policies mentioned in the requirements
3. **EKS connection**: Run `aws eks update-kubeconfig --region <region> --name <cluster-name>`
4. **Load balancer not ready**: Wait 5-10 minutes for ALB provisioning

### Support Commands
```bash
# Check EKS nodes
kubectl get nodes

# Check application pods
kubectl get pods -n unicorn-app

# View pod logs
kubectl logs -l app=unicorn-app -n unicorn-app

# Describe failing pods
kubectl describe pod <pod-name> -n unicorn-app
```

## Time Allocation

- **Infrastructure Setup**: 60-90 minutes
- **Application Deployment**: 15-30 minutes  
- **Testing & Optimization**: 15-30 minutes
- **Buffer for Issues**: 15-30 minutes

**Total**: Under 2 hours to have the application responding to requests!