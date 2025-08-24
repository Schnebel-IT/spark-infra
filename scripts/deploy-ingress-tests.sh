#!/bin/bash

# Deploy ingress test applications and resources
# This script deploys all test applications for ingress validation

set -euo pipefail

# Configuration
TEST_NAMESPACE=${TEST_NAMESPACE:-ingress-tests}
KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create test namespace
create_namespace() {
    log_info "Creating test namespace: $TEST_NAMESPACE"
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    log_success "Namespace created/updated"
}

# Deploy test applications
deploy_applications() {
    log_info "Deploying test applications..."
    
    # Deploy sample application
    log_info "Deploying sample application..."
    kubectl apply -f manifests/ingress-examples/sample-app.yml -n "$TEST_NAMESPACE"
    
    # Deploy sample ingress resources
    log_info "Deploying sample ingress resources..."
    kubectl apply -f manifests/ingress-examples/sample-ingress.yml -n "$TEST_NAMESPACE"
    
    # Deploy NextJS example
    log_info "Deploying NextJS example..."
    kubectl apply -f manifests/ingress-examples/nextjs-example.yml -n "$TEST_NAMESPACE"
    
    # Deploy REST API example
    log_info "Deploying REST API example..."
    kubectl apply -f manifests/ingress-examples/rest-api-example.yml -n "$TEST_NAMESPACE"
    
    # Deploy advanced test scenarios
    log_info "Deploying advanced test scenarios..."
    kubectl apply -f manifests/ingress-examples/advanced-ingress-tests.yml -n "$TEST_NAMESPACE"
    
    log_success "All test applications deployed"
}

# Wait for deployments to be ready
wait_for_deployments() {
    log_info "Waiting for deployments to be ready..."
    
    local timeout=300
    
    # Wait for sample app
    kubectl wait --for=condition=available deployment/sample-app -n "$TEST_NAMESPACE" --timeout="${timeout}s" || log_warning "Sample app deployment timeout"
    
    # Wait for NextJS app
    kubectl wait --for=condition=available deployment/nextjs-app -n "$TEST_NAMESPACE" --timeout="${timeout}s" || log_warning "NextJS app deployment timeout"
    
    # Wait for REST API app
    kubectl wait --for=condition=available deployment/rest-api-app -n "$TEST_NAMESPACE" --timeout="${timeout}s" || log_warning "REST API app deployment timeout"
    
    # Wait for advanced test app
    kubectl wait --for=condition=available deployment/ingress-test-advanced -n "$TEST_NAMESPACE" --timeout="${timeout}s" || log_warning "Advanced test app deployment timeout"
    
    log_success "Deployments are ready"
}

# Display deployment status
show_status() {
    log_info "Deployment Status:"
    echo ""
    
    echo "Deployments:"
    kubectl get deployments -n "$TEST_NAMESPACE" -o wide
    echo ""
    
    echo "Services:"
    kubectl get services -n "$TEST_NAMESPACE" -o wide
    echo ""
    
    echo "Ingress Resources:"
    kubectl get ingress -n "$TEST_NAMESPACE" -o wide
    echo ""
    
    echo "Pods:"
    kubectl get pods -n "$TEST_NAMESPACE" -o wide
    echo ""
}

# Display test instructions
show_test_instructions() {
    local manager_ip=${MANAGER_IP:-10.10.1.1}
    local http_port=${HTTP_PORT:-30080}
    local https_port=${HTTPS_PORT:-30443}
    
    echo "=========================================="
    echo "         INGRESS TEST INSTRUCTIONS"
    echo "=========================================="
    echo ""
    echo "Test URLs (add to /etc/hosts or use curl -H 'Host: ...'):"
    echo ""
    echo "Basic Sample App:"
    echo "  curl -H 'Host: sample.local' http://$manager_ip:$http_port"
    echo ""
    echo "NextJS Application:"
    echo "  curl -H 'Host: nextjs.local' http://$manager_ip:$http_port"
    echo "  curl -H 'Host: nextjs.local' http://$manager_ip:$http_port/api/health"
    echo ""
    echo "REST API:"
    echo "  curl -H 'Host: api.local' http://$manager_ip:$http_port/api/status"
    echo "  curl -H 'Host: api.local' http://$manager_ip:$http_port/api/users"
    echo ""
    echo "Advanced Tests:"
    echo "  curl -H 'Host: advanced.local' http://$manager_ip:$http_port"
    echo "  curl -H 'Host: advanced.local' http://$manager_ip:$http_port/health"
    echo "  curl -H 'Host: advanced.local' http://$manager_ip:$http_port/api/"
    echo ""
    echo "Path-based Routing:"
    echo "  curl -H 'Host: paths.local' http://$manager_ip:$http_port/app/"
    echo "  curl -H 'Host: api.local' http://$manager_ip:$http_port/app"
    echo ""
    echo "Multiple Hosts:"
    echo "  curl -H 'Host: test1.local' http://$manager_ip:$http_port"
    echo "  curl -H 'Host: test2.local' http://$manager_ip:$http_port"
    echo "  curl -H 'Host: test3.local' http://$manager_ip:$http_port"
    echo ""
    echo "HTTPS Tests:"
    echo "  curl -k -H 'Host: sample.local' https://$manager_ip:$https_port"
    echo "  curl -k -H 'Host: nextjs.local' https://$manager_ip:$https_port"
    echo ""
    echo "Validation Scripts:"
    echo "  ./scripts/validate-ingress.sh"
    echo "  ./scripts/test-ingress-comprehensive.sh"
    echo ""
    echo "Cleanup:"
    echo "  kubectl delete namespace $TEST_NAMESPACE"
    echo "=========================================="
}

# Main function
main() {
    log_info "Starting ingress test deployment..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Deploy everything
    create_namespace
    deploy_applications
    wait_for_deployments
    
    # Show status and instructions
    show_status
    show_test_instructions
    
    log_success "Ingress test deployment completed successfully!"
}

# Script usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Deploy ingress test applications and resources"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NAME    Test namespace (default: $TEST_NAMESPACE)"
    echo ""
    echo "Environment Variables:"
    echo "  TEST_NAMESPACE          Test namespace name"
    echo "  KUBECONFIG              Path to kubeconfig file"
    echo "  MANAGER_IP              Kubernetes manager IP for instructions"
    echo "  HTTP_PORT               HTTP NodePort for instructions"
    echo "  HTTPS_PORT              HTTPS NodePort for instructions"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--namespace)
            TEST_NAMESPACE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Run main function
main "$@"