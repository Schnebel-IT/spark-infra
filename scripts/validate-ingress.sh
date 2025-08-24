#!/bin/bash

# nginx-ingress-controller validation and testing script
# This script validates the ingress controller installation and functionality

set -euo pipefail

# Configuration
KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
INGRESS_NAMESPACE=${INGRESS_NAMESPACE:-ingress-nginx}
TEST_NAMESPACE=${TEST_NAMESPACE:-ingress-test}
MANAGER_IP=${MANAGER_IP:-10.10.1.1}
HTTP_PORT=${HTTP_PORT:-30080}
HTTPS_PORT=${HTTPS_PORT:-30443}
TIMEOUT=${TIMEOUT:-300}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check if kubectl is available and configured
check_kubectl() {
    log_info "Checking kubectl configuration..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        return 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl cannot connect to Kubernetes cluster"
        return 1
    fi
    
    log_success "kubectl is configured and connected to cluster"
}

# Check ingress controller installation
check_ingress_installation() {
    log_info "Checking nginx-ingress-controller installation..."
    
    # Check namespace
    if ! kubectl get namespace "$INGRESS_NAMESPACE" &> /dev/null; then
        log_error "Ingress namespace '$INGRESS_NAMESPACE' not found"
        return 1
    fi
    
    # Check Helm release
    if command -v helm &> /dev/null; then
        if ! helm list -n "$INGRESS_NAMESPACE" | grep -q "ingress-nginx"; then
            log_error "nginx-ingress Helm release not found"
            return 1
        fi
        log_success "nginx-ingress Helm release found"
    fi
    
    # Check ingress class
    if ! kubectl get ingressclass nginx &> /dev/null; then
        log_error "nginx ingress class not found"
        return 1
    fi
    
    log_success "nginx-ingress-controller installation verified"
}

# Check ingress controller pods
check_ingress_pods() {
    log_info "Checking ingress controller pods..."
    
    # Check controller pods
    local controller_pods
    controller_pods=$(kubectl get pods -n "$INGRESS_NAMESPACE" -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | wc -l)
    
    if [ "$controller_pods" -eq 0 ]; then
        log_error "No ingress controller pods found"
        return 1
    fi
    
    # Check if pods are ready
    local ready_pods
    ready_pods=$(kubectl get pods -n "$INGRESS_NAMESPACE" -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -c "Running" || true)
    
    if [ "$ready_pods" -ne "$controller_pods" ]; then
        log_error "Not all ingress controller pods are running ($ready_pods/$controller_pods)"
        kubectl get pods -n "$INGRESS_NAMESPACE" -l app.kubernetes.io/component=controller
        return 1
    fi
    
    log_success "All ingress controller pods are running ($ready_pods/$controller_pods)"
}

# Check ingress service
check_ingress_service() {
    log_info "Checking ingress controller service..."
    
    local service_info
    if ! service_info=$(kubectl get service -n "$INGRESS_NAMESPACE" ingress-nginx-controller -o json 2>/dev/null); then
        log_error "Ingress controller service not found"
        return 1
    fi
    
    local service_type
    service_type=$(echo "$service_info" | jq -r '.spec.type')
    
    if [ "$service_type" != "NodePort" ]; then
        log_warning "Service type is '$service_type', expected 'NodePort'"
    fi
    
    local http_nodeport
    local https_nodeport
    http_nodeport=$(echo "$service_info" | jq -r '.spec.ports[] | select(.name=="http") | .nodePort')
    https_nodeport=$(echo "$service_info" | jq -r '.spec.ports[] | select(.name=="https") | .nodePort')
    
    log_success "Ingress service found - HTTP:$http_nodeport, HTTPS:$https_nodeport"
}

# Test ingress controller health
test_ingress_health() {
    log_info "Testing ingress controller health..."
    
    local health_url="http://$MANAGER_IP:$HTTP_PORT/healthz"
    
    if curl -s -f "$health_url" > /dev/null; then
        log_success "Ingress controller health check passed"
    else
        log_error "Ingress controller health check failed"
        log_info "Attempted URL: $health_url"
        return 1
    fi
}

# Create test namespace
create_test_namespace() {
    log_info "Creating test namespace..."
    
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    log_success "Test namespace '$TEST_NAMESPACE' ready"
}

# Deploy test application
deploy_test_application() {
    log_info "Deploying test application..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ingress-test-app
  namespace: $TEST_NAMESPACE
  labels:
    app: ingress-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ingress-test
  template:
    metadata:
      labels:
        app: ingress-test
    spec:
      containers:
      - name: test-app
        image: nginx:alpine
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: 50m
            memory: 64Mi
          requests:
            cpu: 10m
            memory: 32Mi
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        configMap:
          name: test-app-html
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-app-html
  namespace: $TEST_NAMESPACE
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head>
        <title>Ingress Test Application</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .success { color: green; }
            .info { color: blue; }
        </style>
    </head>
    <body>
        <h1 class="success">✓ Ingress Test Successful!</h1>
        <p class="info">This page is served through nginx-ingress-controller</p>
        <p><strong>Timestamp:</strong> $(date)</p>
        <p><strong>Hostname:</strong> $(hostname)</p>
        <p><strong>Namespace:</strong> $TEST_NAMESPACE</p>
    </body>
    </html>
---
apiVersion: v1
kind: Service
metadata:
  name: ingress-test-service
  namespace: $TEST_NAMESPACE
spec:
  selector:
    app: ingress-test
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF

    # Wait for deployment to be ready
    kubectl wait --for=condition=available deployment/ingress-test-app -n "$TEST_NAMESPACE" --timeout="${TIMEOUT}s"
    log_success "Test application deployed and ready"
}

# Create test ingress resources
create_test_ingress() {
    log_info "Creating test ingress resources..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test-basic
  namespace: $TEST_NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ingress-test-service
            port:
              number: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-test-path
  namespace: $TEST_NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: ingress-test-service
            port:
              number: 80
EOF

    # Wait for ingress to get an address
    local retries=0
    while [ $retries -lt 30 ]; do
        if kubectl get ingress ingress-test-basic -n "$TEST_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q .; then
            break
        fi
        sleep 2
        ((retries++))
    done
    
    log_success "Test ingress resources created"
}

# Test ingress functionality
test_ingress_functionality() {
    log_info "Testing ingress functionality..."
    
    local test_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    
    # Test basic ingress with Host header
    log_info "Testing basic ingress routing..."
    if curl -s -H "Host: test.local" "$test_url" | grep -q "Ingress Test Successful"; then
        log_success "Basic ingress routing test passed"
        ((success++))
    else
        log_error "Basic ingress routing test failed"
    fi
    
    # Test path-based routing
    log_info "Testing path-based routing..."
    if curl -s -H "Host: test.local" "$test_url/app" | grep -q "Ingress Test Successful"; then
        log_success "Path-based routing test passed"
        ((success++))
    else
        log_error "Path-based routing test failed"
    fi
    
    # Test default backend (should return 404)
    log_info "Testing default backend..."
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$test_url")
    if [ "$status_code" = "404" ]; then
        log_success "Default backend test passed (404 as expected)"
        ((success++))
    else
        log_warning "Default backend returned status $status_code (expected 404)"
    fi
    
    return $((3 - success))
}

# Test HTTPS functionality (basic)
test_https_functionality() {
    log_info "Testing HTTPS functionality..."
    
    local https_url="https://$MANAGER_IP:$HTTPS_PORT"
    
    # Test HTTPS endpoint (ignore certificate errors for self-signed)
    if curl -s -k -H "Host: test.local" "$https_url" | grep -q "Ingress Test Successful"; then
        log_success "HTTPS functionality test passed"
    else
        log_warning "HTTPS functionality test failed (this may be expected without proper certificates)"
        return 1
    fi
}

# Performance test
performance_test() {
    log_info "Running basic performance test..."
    
    local test_url="http://$MANAGER_IP:$HTTP_PORT"
    
    # Simple load test with curl
    log_info "Testing concurrent requests..."
    local success_count=0
    local total_requests=10
    
    for i in $(seq 1 $total_requests); do
        if curl -s -H "Host: test.local" "$test_url" > /dev/null; then
            ((success_count++))
        fi
    done
    
    local success_rate=$((success_count * 100 / total_requests))
    
    if [ $success_rate -ge 90 ]; then
        log_success "Performance test passed ($success_count/$total_requests requests successful, $success_rate%)"
    else
        log_warning "Performance test concerns ($success_count/$total_requests requests successful, $success_rate%)"
    fi
}

# Cleanup test resources
cleanup_test_resources() {
    log_info "Cleaning up test resources..."
    
    kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true
    log_success "Test resources cleaned up"
}

# Display ingress information
display_ingress_info() {
    log_info "Ingress Controller Information:"
    
    echo "----------------------------------------"
    echo "Namespace: $INGRESS_NAMESPACE"
    echo "External Access:"
    echo "  HTTP:  http://$MANAGER_IP:$HTTP_PORT"
    echo "  HTTPS: https://$MANAGER_IP:$HTTPS_PORT"
    echo ""
    
    echo "Controller Pods:"
    kubectl get pods -n "$INGRESS_NAMESPACE" -l app.kubernetes.io/component=controller -o wide
    echo ""
    
    echo "Service Details:"
    kubectl get service -n "$INGRESS_NAMESPACE" ingress-nginx-controller
    echo ""
    
    echo "Ingress Classes:"
    kubectl get ingressclass
    echo "----------------------------------------"
}

# Main validation function
main() {
    log_info "Starting nginx-ingress-controller validation..."
    
    local exit_code=0
    
    # Basic checks
    check_kubectl || exit_code=1
    check_ingress_installation || exit_code=1
    check_ingress_pods || exit_code=1
    check_ingress_service || exit_code=1
    test_ingress_health || exit_code=1
    
    # Functional tests
    create_test_namespace || exit_code=1
    deploy_test_application || exit_code=1
    create_test_ingress || exit_code=1
    test_ingress_functionality || exit_code=1
    test_https_functionality || true  # Don't fail on HTTPS issues
    performance_test || true  # Don't fail on performance issues
    
    # Display information
    display_ingress_info
    
    # Cleanup (optional)
    if [ "${CLEANUP:-true}" = "true" ]; then
        cleanup_test_resources
    else
        log_info "Test resources left in namespace '$TEST_NAMESPACE' for manual inspection"
    fi
    
    if [ $exit_code -eq 0 ]; then
        log_success "All ingress validation tests passed!"
    else
        log_error "Some ingress validation tests failed!"
    fi
    
    return $exit_code
}

# Script usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -n, --namespace NAME    Ingress namespace (default: $INGRESS_NAMESPACE)"
    echo "  -t, --test-ns NAME      Test namespace (default: $TEST_NAMESPACE)"
    echo "  -i, --ip ADDRESS        Manager IP address (default: $MANAGER_IP)"
    echo "  -p, --http-port PORT    HTTP NodePort (default: $HTTP_PORT)"
    echo "  -s, --https-port PORT   HTTPS NodePort (default: $HTTPS_PORT)"
    echo "  --no-cleanup            Don't cleanup test resources"
    echo "  --timeout SECONDS       Timeout for operations (default: $TIMEOUT)"
    echo ""
    echo "Environment Variables:"
    echo "  KUBECONFIG             Path to kubeconfig file"
    echo "  INGRESS_NAMESPACE      Ingress controller namespace"
    echo "  TEST_NAMESPACE         Test resources namespace"
    echo "  MANAGER_IP             Kubernetes manager IP"
    echo "  HTTP_PORT              HTTP NodePort"
    echo "  HTTPS_PORT             HTTPS NodePort"
    echo "  CLEANUP                Set to 'false' to skip cleanup"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -n|--namespace)
            INGRESS_NAMESPACE="$2"
            shift 2
            ;;
        -t|--test-ns)
            TEST_NAMESPACE="$2"
            shift 2
            ;;
        -i|--ip)
            MANAGER_IP="$2"
            shift 2
            ;;
        -p|--http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        -s|--https-port)
            HTTPS_PORT="$2"
            shift 2
            ;;
        --no-cleanup)
            CLEANUP="false"
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
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