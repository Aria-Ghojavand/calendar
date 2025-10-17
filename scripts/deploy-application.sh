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

# Check if infrastructure is deployed
check_infrastructure() {
    log_info "Checking infrastructure status..."
    
    if [ ! -f "$PROJECT_ROOT/outputs.json" ]; then
        log_error "Infrastructure outputs not found. Please run './scripts/deploy-infrastructure.sh' first."
        exit 1
    fi
    
    # Test kubectl connection
    if ! kubectl get nodes &> /dev/null; then
        log_error "Cannot connect to EKS cluster. Please check your kubectl configuration."
        exit 1
    fi
    
    log_info "Infrastructure is ready."
}

# Substitute variables in Kubernetes manifests
prepare_manifests() {
    log_info "Preparing Kubernetes manifests..."
    
    # Read Terraform outputs
    ECR_REPO_URL=$(jq -r '.ecr_repository_url.value' "$PROJECT_ROOT/outputs.json")
    EFS_ID=$(jq -r '.efs_id.value' "$PROJECT_ROOT/outputs.json")
    EFS_ACCESS_POINT_ID=$(jq -r '.efs_access_point_id.value' "$PROJECT_ROOT/outputs.json")
    DB_SECRET_ARN=$(jq -r '.db_secret_arn.value' "$PROJECT_ROOT/outputs.json")
    APPCONFIG_APPLICATION_ID=$(jq -r '.appconfig_application_id.value' "$PROJECT_ROOT/outputs.json")
    APPCONFIG_ENVIRONMENT_ID=$(jq -r '.appconfig_environment_id.value' "$PROJECT_ROOT/outputs.json")
    APPCONFIG_CONFIGURATION_PROFILE_ID=$(jq -r '.appconfig_configuration_profile_id.value' "$PROJECT_ROOT/outputs.json")
    UNICORN_APP_ROLE_ARN=$(jq -r '.unicorn_app_role_arn.value' "$PROJECT_ROOT/outputs.json")
    AWS_LB_CONTROLLER_ROLE_ARN=$(jq -r '.load_balancer_controller_role_arn.value' "$PROJECT_ROOT/outputs.json")
    CLUSTER_AUTOSCALER_ROLE_ARN=$(jq -r '.cluster_autoscaler_role_arn.value' "$PROJECT_ROOT/outputs.json")
    EFS_CSI_DRIVER_ROLE_ARN=$(jq -r '.efs_csi_driver_role_arn.value' "$PROJECT_ROOT/outputs.json")
    AWS_REGION=$(aws configure get region || echo "us-west-2")
    
    # Base64 encode the secret ARN
    DB_SECRET_ARN_B64=$(echo -n "$DB_SECRET_ARN" | base64)
    
    # Create temp directory for processed manifests
    TEMP_DIR=$(mktemp -d)
    
    # Process each manifest file
    for manifest in "$PROJECT_ROOT"/kubernetes/*.yaml; do
        filename=$(basename "$manifest")
        log_info "Processing $filename..."
        
        sed -e "s|\${ECR_REPOSITORY_URL}|$ECR_REPO_URL|g" \
            -e "s|\${EFS_ID}|$EFS_ID|g" \
            -e "s|\${EFS_ACCESS_POINT_ID}|$EFS_ACCESS_POINT_ID|g" \
            -e "s|\${DB_SECRET_ARN_B64}|$DB_SECRET_ARN_B64|g" \
            -e "s|\${APPCONFIG_APPLICATION_ID}|$APPCONFIG_APPLICATION_ID|g" \
            -e "s|\${APPCONFIG_ENVIRONMENT_ID}|$APPCONFIG_ENVIRONMENT_ID|g" \
            -e "s|\${APPCONFIG_CONFIGURATION_PROFILE_ID}|$APPCONFIG_CONFIGURATION_PROFILE_ID|g" \
            -e "s|\${UNICORN_APP_ROLE_ARN}|$UNICORN_APP_ROLE_ARN|g" \
            -e "s|\${AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN}|$AWS_LB_CONTROLLER_ROLE_ARN|g" \
            -e "s|\${CLUSTER_AUTOSCALER_ROLE_ARN}|$CLUSTER_AUTOSCALER_ROLE_ARN|g" \
            -e "s|\${EFS_CSI_DRIVER_ROLE_ARN}|$EFS_CSI_DRIVER_ROLE_ARN|g" \
            -e "s|\${AWS_REGION}|$AWS_REGION|g" \
            "$manifest" > "$TEMP_DIR/$filename"
    done
    
    echo "$TEMP_DIR"
}

# Deploy application to Kubernetes
deploy_application() {
    log_info "Deploying application to Kubernetes..."
    
    # Prepare manifests
    MANIFEST_DIR=$(prepare_manifests)
    
    # Apply manifests in order
    log_info "Creating namespace and base resources..."
    kubectl apply -f "$MANIFEST_DIR/01-base.yaml"
    
    log_info "Creating service accounts..."
    kubectl apply -f "$MANIFEST_DIR/04-service-accounts.yaml"
    
    log_info "Creating RBAC resources..."
    kubectl apply -f "$MANIFEST_DIR/05-rbac.yaml"
    
    # Wait for service accounts to be ready
    sleep 10
    
    log_info "Deploying application..."
    kubectl apply -f "$MANIFEST_DIR/02-deployment.yaml"
    
    log_info "Creating services and ingress..."
    kubectl apply -f "$MANIFEST_DIR/03-service.yaml"
    
    # Clean up temp directory
    rm -rf "$MANIFEST_DIR"
    
    log_info "Application deployment completed."
}

# Wait for application to be ready
wait_for_application() {
    log_info "Waiting for application to be ready..."
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=600s deployment/unicorn-app -n unicorn-app
    
    # Wait for ingress to have an address
    log_info "Waiting for load balancer to be provisioned..."
    for i in {1..30}; do
        LB_ADDRESS=$(kubectl get ingress unicorn-ingress -n unicorn-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_ADDRESS" ]; then
            log_info "Load balancer address: $LB_ADDRESS"
            break
        fi
        echo "Waiting for load balancer... ($i/30)"
        sleep 10
    done
    
    if [ -z "$LB_ADDRESS" ]; then
        log_warn "Load balancer address not available yet. Check later with:"
        log_warn "kubectl get ingress unicorn-ingress -n unicorn-app"
    fi
}

# Test application health
test_application() {
    log_info "Testing application health..."
    
    # Get ingress address
    LB_ADDRESS=$(kubectl get ingress unicorn-ingress -n unicorn-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    
    if [ -n "$LB_ADDRESS" ]; then
        log_info "Testing health endpoint..."
        for i in {1..10}; do
            if curl -f -s "http://$LB_ADDRESS/" > /dev/null; then
                log_info "Application is healthy and responding!"
                break
            fi
            echo "Waiting for application to respond... ($i/10)"
            sleep 10
        done
    else
        log_warn "Cannot test application - load balancer address not available yet."
    fi
}

# Display deployment status
display_status() {
    log_info "Deployment Status:"
    echo ""
    
    log_info "Pods:"
    kubectl get pods -n unicorn-app
    echo ""
    
    log_info "Services:"
    kubectl get svc -n unicorn-app
    echo ""
    
    log_info "Ingress:"
    kubectl get ingress -n unicorn-app
    echo ""
    
    log_info "HPA:"
    kubectl get hpa -n unicorn-app
    echo ""
    
    # Get application endpoint
    LB_ADDRESS=$(kubectl get ingress unicorn-ingress -n unicorn-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    if [ -n "$LB_ADDRESS" ]; then
        log_info "Application endpoint: http://$LB_ADDRESS"
        log_info "Submit this endpoint to the GameDay Dashboard!"
    else
        log_warn "Load balancer address not ready yet. Check with:"
        log_warn "kubectl get ingress unicorn-ingress -n unicorn-app"
    fi
}

# Main execution
main() {
    log_info "Starting application deployment..."
    
    check_infrastructure
    deploy_application
    wait_for_application
    test_application
    display_status
    
    log_info "Application deployment completed successfully!"
}

# Run main function
main "$@"