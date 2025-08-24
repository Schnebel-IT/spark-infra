#!/bin/bash

# Comprehensive ingress testing script
# This script performs extensive testing of ingress functionality including
# performance, security, and edge case scenarios

set -euo pipefail

# Configuration
KUBECONFIG=${KUBECONFIG:-/etc/kubernetes/admin.conf}
INGRESS_NAMESPACE=${INGRESS_NAMESPACE:-ingress-nginx}
TEST_NAMESPACE=${TEST_NAMESPACE:-ingress-comprehensive-test}
MANAGER_IP=${MANAGER_IP:-10.10.1.1}
HTTP_PORT=${HTTP_PORT:-30080}
HTTPS_PORT=${HTTPS_PORT:-30443}
TIMEOUT=${TIMEOUT:-300}
CONCURRENT_REQUESTS=${CONCURRENT_REQUESTS:-50}
LOAD_TEST_DURATION=${LOAD_TEST_DURATION:-30}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    ((PASSED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((FAILED_TESTS++))
}

log_test() {
    echo -e "${PURPLE}[TEST]${NC} $1"
    ((TOTAL_TESTS++))
}

# Test result tracking
test_result() {
    local test_name="$1"
    local result="$2"
    
    if [ "$result" -eq 0 ]; then
        log_success "$test_name"
    else
        log_error "$test_name"
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local exit_code=0
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit_code=1
    fi
    
    # Check curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit_code=1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit_code=1
    fi
    
    # Check ingress controller
    if ! kubectl get pods -n "$INGRESS_NAMESPACE" -l app.kubernetes.io/component=controller --no-headers | grep -q "Running"; then
        log_error "Ingress controller not running"
        exit_code=1
    fi
    
    if [ $exit_code -eq 0 ]; then
        log_success "All prerequisites met"
    fi
    
    return $exit_code
}

# Create test namespace and resources
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create namespace
    kubectl create namespace "$TEST_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy comprehensive test applications
    kubectl apply -f manifests/ingress-examples/advanced-ingress-tests.yml -n "$TEST_NAMESPACE"
    kubectl apply -f manifests/ingress-examples/rest-api-example.yml -n "$TEST_NAMESPACE"
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available deployment/ingress-test-advanced -n "$TEST_NAMESPACE" --timeout="${TIMEOUT}s"
    kubectl wait --for=condition=available deployment/rest-api-app -n "$TEST_NAMESPACE" --timeout="${TIMEOUT}s"
    
    log_success "Test environment ready"
}

# Test basic ingress functionality
test_basic_functionality() {
    log_test "Testing basic ingress functionality"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Test basic host routing
    ((total++))
    if curl -s -H "Host: advanced.local" "$base_url" | grep -q "Advanced Ingress Test"; then
        ((success++))
        log_info "✓ Basic host routing works"
    else
        log_error "✗ Basic host routing failed"
    fi
    
    # Test health endpoint
    ((total++))
    if curl -s -H "Host: advanced.local" "$base_url/health" | grep -q "healthy"; then
        ((success++))
        log_info "✓ Health endpoint works"
    else
        log_error "✗ Health endpoint failed"
    fi
    
    # Test API endpoint
    ((total++))
    if curl -s -H "Host: advanced.local" "$base_url/api/" | grep -q "API Endpoint"; then
        ((success++))
        log_info "✓ API endpoint works"
    else
        log_error "✗ API endpoint failed"
    fi
    
    test_result "Basic functionality ($success/$total)" $((total - success))
}

# Test path-based routing
test_path_routing() {
    log_test "Testing path-based routing"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Test path rewriting
    ((total++))
    if curl -s -H "Host: paths.local" "$base_url/app/" | grep -q "Advanced Ingress Test"; then
        ((success++))
        log_info "✓ Path rewriting works"
    else
        log_error "✗ Path rewriting failed"
    fi
    
    # Test service path
    ((total++))
    if curl -s -H "Host: paths.local" "$base_url/service/health" | grep -q "healthy"; then
        ((success++))
        log_info "✓ Service path routing works"
    else
        log_error "✗ Service path routing failed"
    fi
    
    test_result "Path-based routing ($success/$total)" $((total - success))
}

# Test multiple hosts
test_multiple_hosts() {
    log_test "Testing multiple host routing"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    for host in test1.local test2.local test3.local; do
        ((total++))
        if curl -s -H "Host: $host" "$base_url" | grep -q "Advanced Ingress Test"; then
            ((success++))
            log_info "✓ Host $host works"
        else
            log_error "✗ Host $host failed"
        fi
    done
    
    test_result "Multiple hosts ($success/$total)" $((total - success))
}

# Test REST API functionality
test_rest_api() {
    log_test "Testing REST API ingress"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Test API status
    ((total++))
    if curl -s -H "Host: api.local" "$base_url/api/status" | grep -q "REST API Sample"; then
        ((success++))
        log_info "✓ REST API status endpoint works"
    else
        log_error "✗ REST API status endpoint failed"
    fi
    
    # Test GET users
    ((total++))
    if curl -s -H "Host: api.local" "$base_url/api/users" | grep -q "users"; then
        ((success++))
        log_info "✓ REST API GET users works"
    else
        log_error "✗ REST API GET users failed"
    fi
    
    # Test POST users
    ((total++))
    if curl -s -X POST -H "Host: api.local" -H "Content-Type: application/json" \
        -d '{"name":"Test User","email":"test@example.com"}' \
        "$base_url/api/users" | grep -q "Test User"; then
        ((success++))
        log_info "✓ REST API POST users works"
    else
        log_error "✗ REST API POST users failed"
    fi
    
    test_result "REST API functionality ($success/$total)" $((total - success))
}

# Test HTTPS functionality
test_https() {
    log_test "Testing HTTPS functionality"
    
    local https_url="https://$MANAGER_IP:$HTTPS_PORT"
    local success=0
    local total=0
    
    # Test HTTPS basic
    ((total++))
    if curl -s -k -H "Host: advanced.local" "$https_url" | grep -q "Advanced Ingress Test"; then
        ((success++))
        log_info "✓ HTTPS basic routing works"
    else
        log_warning "✗ HTTPS basic routing failed (may be expected without certificates)"
    fi
    
    # Test HTTPS API
    ((total++))
    if curl -s -k -H "Host: api.local" "$https_url/api/status" | grep -q "REST API Sample"; then
        ((success++))
        log_info "✓ HTTPS API routing works"
    else
        log_warning "✗ HTTPS API routing failed (may be expected without certificates)"
    fi
    
    test_result "HTTPS functionality ($success/$total)" $((total - success))
}

# Test ingress annotations and features
test_annotations() {
    log_test "Testing ingress annotations and features"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Test rate limiting (should work but hard to verify without load)
    ((total++))
    if curl -s -H "Host: annotated.local" "$base_url" | grep -q "Advanced Ingress Test"; then
        ((success++))
        log_info "✓ Annotated ingress works"
    else
        log_error "✗ Annotated ingress failed"
    fi
    
    # Test large content handling
    ((total++))
    if curl -s -H "Host: advanced.local" "$base_url/large" | grep -q "Large Content Test"; then
        ((success++))
        log_info "✓ Large content handling works"
    else
        log_error "✗ Large content handling failed"
    fi
    
    # Test timeout handling
    ((total++))
    if timeout 35 curl -s -H "Host: advanced.local" "$base_url/slow" | grep -q "Slow Response Test"; then
        ((success++))
        log_info "✓ Timeout handling works"
    else
        log_warning "✗ Timeout handling may have issues"
    fi
    
    test_result "Annotations and features ($success/$total)" $((total - success))
}

# Performance testing
test_performance() {
    log_test "Testing ingress performance"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Concurrent requests test
    log_info "Running concurrent requests test ($CONCURRENT_REQUESTS requests)..."
    ((total++))
    
    local start_time=$(date +%s)
    local successful_requests=0
    
    for i in $(seq 1 $CONCURRENT_REQUESTS); do
        if curl -s -H "Host: advanced.local" "$base_url/health" > /dev/null 2>&1; then
            ((successful_requests++))
        fi &
    done
    
    wait
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local success_rate=$((successful_requests * 100 / CONCURRENT_REQUESTS))
    
    if [ $success_rate -ge 95 ]; then
        ((success++))
        log_info "✓ Concurrent requests: $successful_requests/$CONCURRENT_REQUESTS successful ($success_rate%) in ${duration}s"
    else
        log_warning "✗ Concurrent requests: $successful_requests/$CONCURRENT_REQUESTS successful ($success_rate%) in ${duration}s"
    fi
    
    # Response time test
    log_info "Testing response times..."
    ((total++))
    
    local response_times=()
    for i in {1..10}; do
        local response_time
        response_time=$(curl -s -w "%{time_total}" -H "Host: advanced.local" "$base_url/health" -o /dev/null)
        response_times+=("$response_time")
    done
    
    local avg_time=0
    for time in "${response_times[@]}"; do
        avg_time=$(echo "$avg_time + $time" | bc -l)
    done
    avg_time=$(echo "scale=3; $avg_time / ${#response_times[@]}" | bc -l)
    
    if (( $(echo "$avg_time < 1.0" | bc -l) )); then
        ((success++))
        log_info "✓ Average response time: ${avg_time}s"
    else
        log_warning "✗ Average response time: ${avg_time}s (may be slow)"
    fi
    
    test_result "Performance tests ($success/$total)" $((total - success))
}

# Test error handling
test_error_handling() {
    log_test "Testing error handling"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Test 404 for non-existent host
    ((total++))
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: nonexistent.local" "$base_url")
    if [ "$status_code" = "404" ]; then
        ((success++))
        log_info "✓ 404 for non-existent host"
    else
        log_error "✗ Expected 404 for non-existent host, got $status_code"
    fi
    
    # Test 404 for non-existent path
    ((total++))
    status_code=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: advanced.local" "$base_url/nonexistent")
    if [ "$status_code" = "404" ]; then
        ((success++))
        log_info "✓ 404 for non-existent path"
    else
        log_error "✗ Expected 404 for non-existent path, got $status_code"
    fi
    
    # Test malformed requests
    ((total++))
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "$base_url")
    if [ "$status_code" = "404" ]; then
        ((success++))
        log_info "✓ Default backend returns 404"
    else
        log_warning "✗ Default backend returned $status_code instead of 404"
    fi
    
    test_result "Error handling ($success/$total)" $((total - success))
}

# Test ingress controller health and metrics
test_controller_health() {
    log_test "Testing ingress controller health"
    
    local success=0
    local total=0
    
    # Test controller health endpoint
    ((total++))
    if curl -s "http://$MANAGER_IP:$HTTP_PORT/healthz" | grep -q "ok"; then
        ((success++))
        log_info "✓ Controller health endpoint works"
    else
        log_error "✗ Controller health endpoint failed"
    fi
    
    # Test metrics endpoint (if available)
    ((total++))
    if curl -s "http://$MANAGER_IP:$HTTP_PORT/metrics" > /dev/null 2>&1; then
        ((success++))
        log_info "✓ Controller metrics endpoint accessible"
    else
        log_warning "✗ Controller metrics endpoint not accessible"
    fi
    
    # Check controller pods status
    ((total++))
    local running_pods
    running_pods=$(kubectl get pods -n "$INGRESS_NAMESPACE" -l app.kubernetes.io/component=controller --no-headers | grep -c "Running" || true)
    if [ "$running_pods" -gt 0 ]; then
        ((success++))
        log_info "✓ Controller pods running ($running_pods)"
    else
        log_error "✗ No controller pods running"
    fi
    
    test_result "Controller health ($success/$total)" $((total - success))
}

# Security tests
test_security() {
    log_test "Testing security features"
    
    local base_url="http://$MANAGER_IP:$HTTP_PORT"
    local success=0
    local total=0
    
    # Test that internal services are not directly accessible
    ((total++))
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$MANAGER_IP:8080" 2>/dev/null || echo "000")
    if [ "$status_code" = "000" ] || [ "$status_code" = "404" ]; then
        ((success++))
        log_info "✓ Internal services not directly accessible"
    else
        log_warning "✗ Internal services may be accessible (status: $status_code)"
    fi
    
    # Test request headers handling
    ((total++))
    if curl -s -H "Host: advanced.local" -H "X-Test-Header: test" "$base_url" | grep -q "Advanced Ingress Test"; then
        ((success++))
        log_info "✓ Custom headers handled correctly"
    else
        log_error "✗ Custom headers not handled correctly"
    fi
    
    test_result "Security tests ($success/$total)" $((total - success))
}

# Cleanup test resources
cleanup() {
    log_info "Cleaning up test resources..."
    
    if [ "${CLEANUP:-true}" = "true" ]; then
        kubectl delete namespace "$TEST_NAMESPACE" --ignore-not-found=true --timeout=60s
        log_success "Test resources cleaned up"
    else
        log_info "Test resources left in namespace '$TEST_NAMESPACE' for manual inspection"
    fi
}

# Display comprehensive test results
display_results() {
    echo ""
    echo "=========================================="
    echo "         COMPREHENSIVE TEST RESULTS"
    echo "=========================================="
    echo ""
    echo "Total Tests:    $TOTAL_TESTS"
    echo "Passed:         $PASSED_TESTS"
    echo "Failed:         $FAILED_TESTS"
    echo "Warnings:       $WARNINGS"
    echo ""
    
    local success_rate=0
    if [ $TOTAL_TESTS -gt 0 ]; then
        success_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi
    
    echo "Success Rate:   $success_rate%"
    echo ""
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All critical tests passed! ✓"
    else
        log_error "$FAILED_TESTS critical test(s) failed! ✗"
    fi
    
    if [ $WARNINGS -gt 0 ]; then
        log_warning "$WARNINGS warning(s) detected"
    fi
    
    echo "=========================================="
}

# Main test execution
main() {
    log_info "Starting comprehensive ingress testing..."
    echo ""
    
    # Prerequisites
    check_prerequisites || exit 1
    
    # Setup
    setup_test_environment
    
    # Wait a bit for services to be ready
    sleep 10
    
    # Run all tests
    test_basic_functionality
    test_path_routing
    test_multiple_hosts
    test_rest_api
    test_https
    test_annotations
    test_performance
    test_error_handling
    test_controller_health
    test_security
    
    # Display results
    display_results
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Script usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Comprehensive ingress testing script"
    echo ""
    echo "Options:"
    echo "  -h, --help                  Show this help message"
    echo "  -n, --namespace NAME        Ingress namespace (default: $INGRESS_NAMESPACE)"
    echo "  -t, --test-ns NAME          Test namespace (default: $TEST_NAMESPACE)"
    echo "  -i, --ip ADDRESS            Manager IP address (default: $MANAGER_IP)"
    echo "  -p, --http-port PORT        HTTP NodePort (default: $HTTP_PORT)"
    echo "  -s, --https-port PORT       HTTPS NodePort (default: $HTTPS_PORT)"
    echo "  -c, --concurrent NUM        Concurrent requests for load test (default: $CONCURRENT_REQUESTS)"
    echo "  -d, --duration SECONDS      Load test duration (default: $LOAD_TEST_DURATION)"
    echo "  --no-cleanup                Don't cleanup test resources"
    echo "  --timeout SECONDS           Timeout for operations (default: $TIMEOUT)"
    echo ""
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
        -c|--concurrent)
            CONCURRENT_REQUESTS="$2"
            shift 2
            ;;
        -d|--duration)
            LOAD_TEST_DURATION="$2"
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

# Check for bc command (needed for calculations)
if ! command -v bc &> /dev/null; then
    log_warning "bc command not found, some calculations may not work"
fi

# Run main function
main "$@"