#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Please run 'aws configure'."
        exit 1
    fi
    
    log_info "All prerequisites are satisfied."
}

# Get the Go binary
get_go_binary() {
    log_info "Downloading Unicorn service binary..."
    
    # This would typically download from the game event location
    # For now, create a placeholder
    if [ ! -f "$PROJECT_ROOT/docker/unicorn-service" ]; then
        log_warn "Unicorn service binary not found."
        log_info "Please download the unicorn-service binary from the game event README and place it at:"
        log_info "  $PROJECT_ROOT/docker/unicorn-service"
        log_info ""
        log_info "Example download command (replace URL with actual from game event):"
        log_info "  curl -o $PROJECT_ROOT/docker/unicorn-service https://example.com/unicorn-service"
        log_info "  chmod +x $PROJECT_ROOT/docker/unicorn-service"
        
        # Create a placeholder for demonstration
        cat > "$PROJECT_ROOT/docker/unicorn-service" << 'EOF'
#!/bin/bash
echo "This is a placeholder for the actual unicorn-service binary"
echo "Please replace this with the actual binary from the game event"
echo "Listening on port 80..."
python3 -m http.server 80
EOF
        chmod +x "$PROJECT_ROOT/docker/unicorn-service"
        log_warn "Created placeholder binary for demonstration. Replace with actual binary!"
    else
        log_info "Unicorn service binary found."
    fi
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."
    
    cd "$PROJECT_ROOT/infrastructure"
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    terraform plan -out=tfplan
    
    # Apply the deployment
    terraform apply tfplan
    
    # Get outputs
    terraform output -json > ../outputs.json
    
    log_info "Infrastructure deployment completed."
}

# Configure kubectl
configure_kubectl() {
    log_info "Configuring kubectl..."
    
    # Get cluster name from Terraform output
    CLUSTER_NAME=$(jq -r '.cluster_id.value' "$PROJECT_ROOT/outputs.json")
    AWS_REGION=$(aws configure get region || echo "us-west-2")
    
    # Update kubeconfig
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    
    # Test connection
    kubectl get nodes
    
    log_info "kubectl configured successfully."
}

# Install EKS add-ons
install_eks_addons() {
    log_info "Installing EKS add-ons..."
    
    # Install AWS Load Balancer Controller
    log_info "Installing AWS Load Balancer Controller..."
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.4/cert-manager.yaml
    
    # Wait for cert-manager to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    
    # Install AWS Load Balancer Controller
    curl -o /tmp/v2_4_7_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.4.7/v2_4_7_full.yaml
    kubectl apply -f /tmp/v2_4_7_full.yaml
    
    # Install EFS CSI Driver
    log_info "Installing EFS CSI Driver..."
    kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.7"
    
    # Install Cluster Autoscaler
    log_info "Installing Cluster Autoscaler..."
    CLUSTER_NAME=$(jq -r '.cluster_id.value' "$PROJECT_ROOT/outputs.json")
    curl -o /tmp/cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
    sed -i "s/<YOUR CLUSTER NAME>/$CLUSTER_NAME/g" /tmp/cluster-autoscaler-autodiscover.yaml
    kubectl apply -f /tmp/cluster-autoscaler-autodiscover.yaml
    
    log_info "EKS add-ons installation completed."
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building and pushing Docker image..."
    
    # Get ECR repository URL from Terraform output
    ECR_REPO_URL=$(jq -r '.ecr_repository_url.value' "$PROJECT_ROOT/outputs.json")
    AWS_REGION=$(aws configure get region || echo "us-west-2")
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    
    # Login to ECR
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
    
    # Build the image
    cd "$PROJECT_ROOT"
    docker build -f docker/Dockerfile -t unicorn-service:latest .
    
    # Tag and push
    docker tag unicorn-service:latest "$ECR_REPO_URL:latest"
    docker push "$ECR_REPO_URL:latest"
    
    log_info "Docker image built and pushed successfully."
}

# Deploy the database schema
deploy_database_schema() {
    log_info "Setting up database schema..."
    
    # Get database connection details from Terraform output
    DB_ENDPOINT=$(jq -r '.rds_endpoint.value' "$PROJECT_ROOT/outputs.json")
    DB_SECRET_ARN=$(jq -r '.db_secret_arn.value' "$PROJECT_ROOT/outputs.json")
    
    # Get database credentials from Secrets Manager
    DB_CREDS=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query SecretString --output text)
    DB_HOST=$(echo "$DB_CREDS" | jq -r '.host')
    DB_PORT=$(echo "$DB_CREDS" | jq -r '.port')
    DB_USER=$(echo "$DB_CREDS" | jq -r '.username')
    DB_PASS=$(echo "$DB_CREDS" | jq -r '.password')
    DB_NAME=$(echo "$DB_CREDS" | jq -r '.dbname')
    
    # Create the unicorns table
    log_info "Creating unicorns table..."
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
    CREATE TABLE IF NOT EXISTS unicorns (
        unicornid varchar(256),
        unicornlocation varchar(256)
    );"
    
    log_info "Database schema setup completed."
}

# Main execution
main() {
    log_info "Starting infrastructure deployment..."
    
    check_prerequisites
    get_go_binary
    deploy_infrastructure
    configure_kubectl
    install_eks_addons
    build_and_push_image
    deploy_database_schema
    
    log_info "Infrastructure deployment completed successfully!"
    log_info "Next steps:"
    log_info "1. Run './scripts/deploy-application.sh' to deploy the application"
    log_info "2. Get the application endpoint with 'kubectl get ingress -n unicorn-app'"
}

# Run main function
main "$@"