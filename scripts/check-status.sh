#!/bin/bash
set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_section() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Check application status
check_application_status() {
    log_section "APPLICATION STATUS"
    
    # Check if infrastructure is deployed
    if [ ! -f "$PROJECT_ROOT/outputs.json" ]; then
        log_error "Infrastructure not deployed. Run './scripts/deploy-infrastructure.sh' first."
        return 1
    fi
    
    # Check EKS connection
    if ! kubectl get nodes &> /dev/null; then
        log_error "Cannot connect to EKS cluster."
        return 1
    fi
    
    log_info "Cluster Status:"
    kubectl get nodes
    echo ""
    
    # Check if application namespace exists
    if kubectl get namespace unicorn-app &> /dev/null; then
        log_info "Application Deployment Status:"
        kubectl get pods,svc,ingress,hpa -n unicorn-app
        echo ""
        
        # Check application health
        log_info "Pod Status Details:"
        kubectl describe pods -n unicorn-app | grep -E "(Name:|Status:|Ready:|Restart Count:|Events:)" || true
        echo ""
        
        # Get application endpoint
        LB_ADDRESS=$(kubectl get ingress unicorn-ingress -n unicorn-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_ADDRESS" ]; then
            log_info "Application Endpoint: http://$LB_ADDRESS"
            
            # Test health endpoint
            log_info "Testing health endpoint..."
            if curl -f -s -m 10 "http://$LB_ADDRESS/" > /dev/null; then
                log_info "✅ Application is healthy and responding!"
            else
                log_warn "⚠️  Application is not responding to health checks"
            fi
        else
            log_warn "Load balancer address not available yet"
        fi
    else
        log_warn "Application not deployed yet. Run './scripts/deploy-application.sh'"
    fi
}

# Check infrastructure status
check_infrastructure_status() {
    log_section "INFRASTRUCTURE STATUS"
    
    if [ ! -f "$PROJECT_ROOT/outputs.json" ]; then
        log_error "Infrastructure not deployed."
        return 1
    fi
    
    # Display key infrastructure components
    log_info "EKS Cluster:"
    CLUSTER_NAME=$(jq -r '.cluster_id.value' "$PROJECT_ROOT/outputs.json")
    echo "  Name: $CLUSTER_NAME"
    echo "  Endpoint: $(jq -r '.cluster_endpoint.value' "$PROJECT_ROOT/outputs.json")"
    echo ""
    
    log_info "RDS Database:"
    echo "  Endpoint: $(jq -r '.rds_endpoint.value' "$PROJECT_ROOT/outputs.json")"
    echo ""
    
    log_info "ElastiCache Redis:"
    echo "  Endpoint: $(jq -r '.redis_endpoint.value' "$PROJECT_ROOT/outputs.json")"
    echo ""
    
    log_info "EFS File System:"
    echo "  ID: $(jq -r '.efs_id.value' "$PROJECT_ROOT/outputs.json")"
    echo ""
    
    log_info "ECR Repository:"
    echo "  URL: $(jq -r '.ecr_repository_url.value' "$PROJECT_ROOT/outputs.json")"
    echo ""
}

# Check costs and resources
check_resources() {
    log_section "RESOURCE UTILIZATION"
    
    if kubectl get nodes &> /dev/null; then
        log_info "Node Resource Usage:"
        kubectl top nodes 2>/dev/null || log_warn "Metrics server not available"
        echo ""
        
        log_info "Pod Resource Usage:"
        kubectl top pods -n unicorn-app 2>/dev/null || log_warn "Pod metrics not available"
        echo ""
        
        log_info "HPA Status:"
        kubectl get hpa -n unicorn-app 2>/dev/null || log_warn "HPA not deployed"
        echo ""
    fi
}

# Monitor application logs
monitor_logs() {
    log_section "APPLICATION LOGS"
    
    if kubectl get pods -n unicorn-app &> /dev/null; then
        log_info "Recent application logs:"
        kubectl logs -n unicorn-app -l app=unicorn-app --tail=20 --since=5m
    else
        log_warn "No application pods found"
    fi
}

# Display helpful commands
show_helpful_commands() {
    log_section "HELPFUL COMMANDS"
    
    echo "🔍 Monitoring Commands:"
    echo "  kubectl get pods -n unicorn-app -w"
    echo "  kubectl logs -n unicorn-app -l app=unicorn-app -f"
    echo "  kubectl describe pod <pod-name> -n unicorn-app"
    echo ""
    
    echo "📊 Scaling Commands:"
    echo "  kubectl scale deployment unicorn-app --replicas=5 -n unicorn-app"
    echo "  kubectl get hpa -n unicorn-app"
    echo ""
    
    echo "🔧 Debugging Commands:"
    echo "  kubectl exec -it <pod-name> -n unicorn-app -- /bin/sh"
    echo "  kubectl port-forward svc/unicorn-service 8080:80 -n unicorn-app"
    echo ""
    
    echo "📈 Performance Testing:"
    echo "  # Install hey tool: go install github.com/rakyll/hey@latest"
    echo "  hey -n 1000 -c 10 http://<load-balancer-address>/"
    echo ""
    
    echo "🎯 GameDay Dashboard:"
    if [ -f "$PROJECT_ROOT/outputs.json" ]; then
        LB_ADDRESS=$(kubectl get ingress unicorn-ingress -n unicorn-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ -n "$LB_ADDRESS" ]; then
            echo "  Submit this endpoint: http://$LB_ADDRESS"
        else
            echo "  Get endpoint with: kubectl get ingress unicorn-ingress -n unicorn-app"
        fi
    fi
    echo ""
}

# Main execution
main() {
    case "${1:-status}" in
        "status"|"")
            check_infrastructure_status
            check_application_status
            check_resources
            ;;
        "logs")
            monitor_logs
            ;;
        "help")
            show_helpful_commands
            ;;
        "full")
            check_infrastructure_status
            check_application_status
            check_resources
            monitor_logs
            show_helpful_commands
            ;;
        *)
            echo "Usage: $0 [status|logs|help|full]"
            echo ""
            echo "Commands:"
            echo "  status (default) - Show infrastructure and application status"
            echo "  logs            - Show recent application logs"
            echo "  help            - Show helpful commands"
            echo "  full            - Show everything"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"