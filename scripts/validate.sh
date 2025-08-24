#!/bin/bash

# sit-spark Kubernetes Cluster Validation Script
# This script performs comprehensive health checks on the Kubernetes cluster
# Author: sit-spark Infrastructure Team
# Version: 1.0

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"
LOG_FILE="$PROJECT_ROOT/validation.log"

# Validation results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Default values
VERBOSE=false
QUICK_CHECK=false
SKIP_CONNECTIVITY=false

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}" | tee -a "$LOG_FILE"
}

print_info() {
    print_status "$BLUE" "INFO: $1"
}

print_success() {
    print_status "$GREEN" "SUCCESS: $1"
}

print_warning() {
    print_status "$YELLOW" "WARNING: $1"
}

print_error() {
    print_status "$RED" "ERROR: $1"
}

# Function to run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local is_critical="${3:-true}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    print_info "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        print_success "✓ $test_name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        if [ "$is_critical" = "true" ]; then
            print_error "✗ $test_name (CRITICAL)"
        else
            print_warning "✗ $test_name (WARNING)"
        fi
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate sit-spark Kubernetes cluster health and functionality

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -q, --quick             Run only quick health checks
    --skip-connectivity     Skip external connectivity tests

EXAMPLES:
    $0                      # Full validation
    $0 --verbose            # Full validation with verbose output
    $0 --quick              # Quick health check only

EOF
}

# Function to check if we're running on the manager node
check_manager_node() {
    print_info "Checking if running on Kubernetes manager node..."
    
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl not found - this script should run on the Kubernetes manager node"
        return 1
    fi
    
    if ! kubectl cluster-info >/dev/null 2>&1; then
        print_error "Cannot connect to Kubernetes cluster - ensure you're on the manager node"
        return 1
    fi
    
    print_success "Running on Kubernetes manager node"
    return 0
}

# Function to validate cluster nodes
validate_cluster_nodes() {
    print_info "=== Validating Cluster Nodes ==="
    
    # Check if all nodes are ready
    run_test "All nodes are Ready" \
        "kubectl get nodes --no-headers | grep -v Ready | wc -l | grep -q '^0$'"
    
    # Check expected number of nodes (1 manager + 3 workers = 4 total)
    run_test "Expected number of nodes (4)" \
        "kubectl get nodes --no-headers | wc -l | grep -q '^4$'"
    
    # Check node roles
    run_test "Manager node has control-plane role" \
        "kubectl get nodes --no-headers | grep -q 'control-plane'"
    
    # Check node versions
    run_test "All nodes running same Kubernetes version" \
        "kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}' | tr ' ' '\n' | sort -u | wc -l | grep -q '^1$'"
    
    if [ "$VERBOSE" = true ]; then
        print_info "Node details:"
        kubectl get nodes -o wide | tee -a "$LOG_FILE"
    fi
}

# Function to validate system pods
validate_system_pods() {
    print_info "=== Validating System Pods ==="
    
    # Check kube-system pods
    run_test "All kube-system pods are running" \
        "kubectl get pods -n kube-system --no-headers | grep -v Running | grep -v Completed | wc -l | grep -q '^0$'"
    
    # Check specific critical pods
    local critical_pods=("kube-apiserver" "kube-controller-manager" "kube-scheduler" "etcd")
    
    for pod in "${critical_pods[@]}"; do
        run_test "$pod pod is running" \
            "kubectl get pods -n kube-system --no-headers | grep $pod | grep -q Running"
    done
    
    # Check CNI pods (Calico or Flannel)
    run_test "CNI pods are running" \
        "kubectl get pods -n kube-system --no-headers | grep -E '(calico|flannel)' | grep -v Running | wc -l | grep -q '^0$'"
    
    if [ "$VERBOSE" = true ]; then
        print_info "System pods status:"
        kubectl get pods -n kube-system | tee -a "$LOG_FILE"
    fi
}

# Function to validate networking
validate_networking() {
    print_info "=== Validating Cluster Networking ==="
    
    # Check cluster DNS
    run_test "CoreDNS pods are running" \
        "kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers | grep -v Running | wc -l | grep -q '^0$'"
    
    # Test DNS resolution
    run_test "DNS resolution works" \
        "kubectl run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default.svc.cluster.local" \
        false
    
    # Check service connectivity
    run_test "Kubernetes API service is accessible" \
        "kubectl get svc kubernetes -o jsonpath='{.spec.clusterIP}' | xargs -I {} kubectl run api-test --image=busybox --rm -it --restart=Never -- wget -qO- https://{}:443 --no-check-certificate" \
        false
    
    if [ "$VERBOSE" = true ]; then
        print_info "Network configuration:"
        kubectl get svc -A | tee -a "$LOG_FILE"
    fi
}

# Function to validate Helm installation
validate_helm() {
    print_info "=== Validating Helm Installation ==="
    
    # Check if Helm is installed
    run_test "Helm is installed" \
        "command -v helm"
    
    # Check Helm version
    run_test "Helm version is accessible" \
        "helm version --short"
    
    # Check Helm repositories
    run_test "Helm repositories are configured" \
        "helm repo list | grep -q ingress-nginx"
    
    if [ "$VERBOSE" = true ]; then
        print_info "Helm repositories:"
        helm repo list | tee -a "$LOG_FILE"
    fi
}

# Function to validate ingress controller
validate_ingress_controller() {
    print_info "=== Validating Ingress Controller ==="
    
    # Check ingress-nginx namespace
    run_test "ingress-nginx namespace exists" \
        "kubectl get namespace ingress-nginx"
    
    # Check ingress controller pods
    run_test "Ingress controller pods are running" \
        "kubectl get pods -n ingress-nginx --no-headers | grep -v Running | wc -l | grep -q '^0$'"
    
    # Check ingress controller service
    run_test "Ingress controller service exists" \
        "kubectl get svc -n ingress-nginx ingress-nginx-controller"
    
    # Check if ingress class is available
    run_test "nginx IngressClass is available" \
        "kubectl get ingressclass nginx"
    
    if [ "$VERBOSE" = true ]; then
        print_info "Ingress controller status:"
        kubectl get all -n ingress-nginx | tee -a "$LOG_FILE"
    fi
}

# Function to test connectivity between nodes
test_node_connectivity() {
    if [ "$SKIP_CONNECTIVITY" = true ]; then
        print_info "Skipping connectivity tests (--skip-connectivity specified)"
        return 0
    fi
    
    print_info "=== Testing Node Connectivity ==="
    
    # Get node IPs
    local node_ips
    node_ips=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    
    # Test connectivity between nodes
    for source_ip in $node_ips; do
        for target_ip in $node_ips; do
            if [ "$source_ip" != "$target_ip" ]; then
                run_test "Connectivity from $source_ip to $target_ip" \
                    "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$source_ip 'ping -c 1 $target_ip'" \
                    false
            fi
        done
    done
}

# Function to test external connectivity
test_external_connectivity() {
    if [ "$SKIP_CONNECTIVITY" = true ]; then
        print_info "Skipping external connectivity tests (--skip-connectivity specified)"
        return 0
    fi
    
    print_info "=== Testing External Connectivity ==="
    
    # Test internet connectivity from nodes
    local node_ips
    node_ips=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    
    for ip in $node_ips; do
        run_test "Internet connectivity from $ip" \
            "ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@$ip 'curl -s --connect-timeout 5 https://www.google.com'" \
            false
    done
    
    # Test ingress external access
    local ingress_ip
    ingress_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    
    run_test "Ingress controller external access" \
        "curl -s --connect-timeout 5 http://$ingress_ip:30080" \
        false
}

# Function to run application deployment test
test_application_deployment() {
    if [ "$QUICK_CHECK" = true ]; then
        print_info "Skipping application deployment test (--quick specified)"
        return 0
    fi
    
    print_info "=== Testing Application Deployment ==="
    
    # Deploy a test application
    local test_app_name="validation-test-app"
    
    print_info "Deploying test application..."
    
    # Create test deployment
    kubectl create deployment "$test_app_name" --image=nginx:alpine --replicas=2 >/dev/null 2>&1 || true
    
    # Wait for deployment to be ready
    run_test "Test application deployment is ready" \
        "kubectl wait --for=condition=available --timeout=120s deployment/$test_app_name"
    
    # Expose the deployment
    kubectl expose deployment "$test_app_name" --port=80 --target-port=80 >/dev/null 2>&1 || true
    
    # Test service connectivity
    run_test "Test application service is accessible" \
        "kubectl run test-client --image=busybox --rm -it --restart=Never -- wget -qO- http://$test_app_name" \
        false
    
    # Cleanup test application
    print_info "Cleaning up test application..."
    kubectl delete deployment "$test_app_name" >/dev/null 2>&1 || true
    kubectl delete service "$test_app_name" >/dev/null 2>&1 || true
}

# Function to check resource usage
check_resource_usage() {
    print_info "=== Checking Resource Usage ==="
    
    # Check node resource usage
    run_test "Node CPU usage is reasonable (<80%)" \
        "kubectl top nodes --no-headers | awk '{print \$3}' | sed 's/%//' | awk '{if(\$1<80) print \"ok\"}' | grep -q ok" \
        false
    
    run_test "Node memory usage is reasonable (<80%)" \
        "kubectl top nodes --no-headers | awk '{print \$5}' | sed 's/%//' | awk '{if(\$1<80) print \"ok\"}' | grep -q ok" \
        false
    
    if [ "$VERBOSE" = true ]; then
        print_info "Resource usage:"
        kubectl top nodes | tee -a "$LOG_FILE"
        kubectl top pods -A | head -20 | tee -a "$LOG_FILE"
    fi
}

# Function to validate cluster configuration
validate_cluster_config() {
    print_info "=== Validating Cluster Configuration ==="
    
    # Check cluster info
    run_test "Cluster info is accessible" \
        "kubectl cluster-info"
    
    # Check API server
    run_test "API server is responsive" \
        "kubectl get --raw /healthz | grep -q ok"
    
    # Check RBAC
    run_test "RBAC is enabled" \
        "kubectl auth can-i create pods --as=system:serviceaccount:default:default" \
        false
    
    if [ "$VERBOSE" = true ]; then
        print_info "Cluster information:"
        kubectl cluster-info | tee -a "$LOG_FILE"
    fi
}

# Function to show validation summary
show_validation_summary() {
    print_info "=== Validation Summary ==="
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    cat << EOF | tee -a "$LOG_FILE"
==========================================
Kubernetes Cluster Validation Results
==========================================
Total Tests: $TOTAL_TESTS
Passed: $PASSED_TESTS
Failed: $FAILED_TESTS
Success Rate: $success_rate%

EOF
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "All validation tests passed! Cluster is healthy."
        return 0
    elif [ $success_rate -ge 80 ]; then
        print_warning "Most tests passed ($success_rate%). Some non-critical issues detected."
        return 0
    else
        print_error "Validation failed with $FAILED_TESTS failures. Please investigate."
        return 1
    fi
}

# Main validation function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -q|--quick)
                QUICK_CHECK=true
                shift
                ;;
            --skip-connectivity)
                SKIP_CONNECTIVITY=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    echo "=== sit-spark Kubernetes Validation Started at $(date) ===" > "$LOG_FILE"
    
    print_info "Starting sit-spark Kubernetes cluster validation"
    print_info "Log file: $LOG_FILE"
    
    # Check if we're on the manager node
    if ! check_manager_node; then
        exit 1
    fi
    
    # Run validation tests
    validate_cluster_config
    validate_cluster_nodes
    validate_system_pods
    validate_networking
    validate_helm
    validate_ingress_controller
    
    if [ "$QUICK_CHECK" = false ]; then
        test_node_connectivity
        test_external_connectivity
        test_application_deployment
        check_resource_usage
    fi
    
    # Show summary and exit with appropriate code
    if show_validation_summary; then
        echo "=== sit-spark Kubernetes Validation Completed Successfully at $(date) ===" >> "$LOG_FILE"
        exit 0
    else
        echo "=== sit-spark Kubernetes Validation Failed at $(date) ===" >> "$LOG_FILE"
        exit 1
    fi
}

# Run main function
main "$@"