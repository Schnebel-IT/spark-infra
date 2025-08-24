#!/bin/bash

# sit-spark Kubernetes Cluster Deployment Script
# This script orchestrates the complete deployment of a Kubernetes cluster on Proxmox VE
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
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
LOG_FILE="$PROJECT_ROOT/deployment.log"

# Default values
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false
FORCE_DESTROY=false
VERBOSE=false

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy sit-spark Kubernetes cluster on Proxmox VE

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    --skip-terraform        Skip Terraform infrastructure provisioning
    --skip-ansible          Skip Ansible configuration management
    --force-destroy         Force destroy existing infrastructure before deployment
    --terraform-only        Only run Terraform (skip Ansible)
    --ansible-only          Only run Ansible (skip Terraform)

EXAMPLES:
    $0                      # Full deployment
    $0 --verbose            # Full deployment with verbose output
    $0 --skip-terraform     # Only run Ansible configuration
    $0 --terraform-only     # Only provision infrastructure

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    command -v ansible-playbook >/dev/null 2>&1 || missing_tools+=("ansible")
    command -v ssh >/dev/null 2>&1 || missing_tools+=("ssh")
    command -v curl >/dev/null 2>&1 || missing_tools+=("curl")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again"
        exit 1
    fi
    
    # Check if required files exist
    local required_files=(
        "$TERRAFORM_DIR/main.tf"
        "$TERRAFORM_DIR/variables.tf"
        "$TERRAFORM_DIR/terraform.tfvars"
        "$ANSIBLE_DIR/site.yml"
        "$ANSIBLE_DIR/inventory/hosts"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            print_error "Required file not found: $file"
            exit 1
        fi
    done
    
    print_success "All prerequisites met"
}

# Function to check Proxmox connectivity
check_proxmox_connectivity() {
    print_info "Checking Proxmox connectivity..."
    
    # Extract Proxmox API URL from terraform.tfvars
    local proxmox_url
    proxmox_url=$(grep -E '^proxmox_api_url' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    
    if [ -z "$proxmox_url" ]; then
        print_error "Could not find Proxmox API URL in terraform.tfvars"
        exit 1
    fi
    
    # Remove /api2/json from URL for basic connectivity test
    local base_url
    base_url=$(echo "$proxmox_url" | sed 's|/api2/json||')
    
    print_info "Testing connectivity to Proxmox at: $base_url"
    
    if curl -k -s --connect-timeout 10 "$base_url" >/dev/null; then
        print_success "Proxmox connectivity verified"
    else
        print_error "Cannot connect to Proxmox at $base_url"
        print_error "Please check your network connection and Proxmox configuration"
        exit 1
    fi
}

# Function to validate Terraform configuration
validate_terraform() {
    print_info "Validating Terraform configuration..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform
    if ! terraform init; then
        print_error "Terraform initialization failed"
        exit 1
    fi
    
    # Validate configuration
    if ! terraform validate; then
        print_error "Terraform validation failed"
        exit 1
    fi
    
    # Check if terraform.tfvars contains sensitive information
    if grep -q "password.*=" "$TERRAFORM_DIR/terraform.tfvars"; then
        print_warning "Terraform configuration contains passwords in plain text"
        print_warning "Consider using environment variables or Terraform Cloud for production"
    fi
    
    print_success "Terraform configuration is valid"
    cd "$PROJECT_ROOT"
}

# Function to run Terraform
run_terraform() {
    print_info "Starting Terraform infrastructure provisioning..."
    
    cd "$TERRAFORM_DIR"
    
    # Show plan
    print_info "Generating Terraform execution plan..."
    if [ "$VERBOSE" = true ]; then
        terraform plan
    else
        terraform plan -no-color | tee -a "$LOG_FILE"
    fi
    
    # Apply changes
    print_info "Applying Terraform configuration..."
    if [ "$VERBOSE" = true ]; then
        terraform apply -auto-approve
    else
        terraform apply -auto-approve -no-color | tee -a "$LOG_FILE"
    fi
    
    # Verify outputs
    print_info "Verifying Terraform outputs..."
    terraform output | tee -a "$LOG_FILE"
    
    print_success "Terraform infrastructure provisioning completed"
    cd "$PROJECT_ROOT"
}

# Function to wait for VMs to be ready
wait_for_vms() {
    print_info "Waiting for VMs to be ready..."
    
    # Extract VM IPs from Terraform outputs or tfvars
    local manager_ip
    local node_ips
    
    manager_ip=$(grep -E '^manager_ip' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    node_ips=$(grep -E '^node_ips' "$TERRAFORM_DIR/terraform.tfvars" | sed 's/.*\[\(.*\)\].*/\1/' | tr -d '"' | tr ',' ' ')
    
    local all_ips="$manager_ip $node_ips"
    
    print_info "Testing SSH connectivity to VMs: $all_ips"
    
    for ip in $all_ips; do
        local retries=0
        local max_retries=30
        
        print_info "Waiting for SSH on $ip..."
        
        while [ $retries -lt $max_retries ]; do
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$ip" "echo 'SSH Ready'" >/dev/null 2>&1; then
                print_success "SSH ready on $ip"
                break
            fi
            
            retries=$((retries + 1))
            print_info "SSH not ready on $ip, attempt $retries/$max_retries..."
            sleep 10
        done
        
        if [ $retries -eq $max_retries ]; then
            print_error "SSH connection to $ip failed after $max_retries attempts"
            exit 1
        fi
    done
    
    print_success "All VMs are ready for configuration"
}

# Function to run Ansible
run_ansible() {
    print_info "Starting Ansible configuration management..."
    
    cd "$ANSIBLE_DIR"
    
    # Verify inventory
    print_info "Verifying Ansible inventory..."
    if ! ansible-inventory --list >/dev/null 2>&1; then
        print_error "Ansible inventory validation failed"
        exit 1
    fi
    
    # Test connectivity
    print_info "Testing Ansible connectivity to all hosts..."
    if ! ansible all -m ping; then
        print_error "Ansible connectivity test failed"
        print_error "Please check SSH keys and host connectivity"
        exit 1
    fi
    
    # Run main playbook
    print_info "Executing Ansible playbook..."
    local ansible_cmd="ansible-playbook site.yml"
    
    if [ "$VERBOSE" = true ]; then
        ansible_cmd="$ansible_cmd -v"
    fi
    
    if ! $ansible_cmd; then
        print_error "Ansible playbook execution failed"
        exit 1
    fi
    
    print_success "Ansible configuration management completed"
    cd "$PROJECT_ROOT"
}

# Function to perform post-deployment validation
post_deployment_validation() {
    print_info "Performing post-deployment validation..."
    
    # Run validation script if it exists
    if [ -f "$SCRIPT_DIR/validate.sh" ]; then
        print_info "Running cluster validation script..."
        if bash "$SCRIPT_DIR/validate.sh"; then
            print_success "Cluster validation passed"
        else
            print_warning "Cluster validation failed - please check manually"
        fi
    else
        print_warning "Validation script not found, skipping automated validation"
    fi
}

# Function to show deployment summary
show_deployment_summary() {
    print_info "Deployment Summary"
    echo "===========================================" | tee -a "$LOG_FILE"
    
    # Extract key information
    local manager_ip
    manager_ip=$(grep -E '^manager_ip' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    
    cat << EOF | tee -a "$LOG_FILE"
Kubernetes Cluster Deployment Completed Successfully!

Manager Node: $manager_ip
Access Command: ssh root@$manager_ip

Next Steps:
1. Connect to the manager node: ssh root@$manager_ip
2. Verify cluster status: kubectl get nodes
3. Check ingress controller: kubectl get pods -n ingress-nginx
4. Deploy your applications using the examples in manifests/

Log file: $LOG_FILE
EOF
    
    print_success "Deployment completed successfully!"
}

# Function to cleanup on error
cleanup_on_error() {
    print_error "Deployment failed. Check the log file: $LOG_FILE"
    print_info "You can retry the deployment or run with --force-destroy to start fresh"
    exit 1
}

# Main deployment function
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
            --skip-terraform)
                SKIP_TERRAFORM=true
                shift
                ;;
            --skip-ansible)
                SKIP_ANSIBLE=true
                shift
                ;;
            --terraform-only)
                SKIP_ANSIBLE=true
                shift
                ;;
            --ansible-only)
                SKIP_TERRAFORM=true
                shift
                ;;
            --force-destroy)
                FORCE_DESTROY=true
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
    echo "=== sit-spark Kubernetes Deployment Started at $(date) ===" > "$LOG_FILE"
    
    print_info "Starting sit-spark Kubernetes cluster deployment"
    print_info "Project root: $PROJECT_ROOT"
    print_info "Log file: $LOG_FILE"
    
    # Set trap for cleanup on error
    trap cleanup_on_error ERR
    
    # Run deployment steps
    check_prerequisites
    check_proxmox_connectivity
    
    if [ "$FORCE_DESTROY" = true ]; then
        print_warning "Force destroy requested - cleaning up existing infrastructure"
        if [ -f "$SCRIPT_DIR/destroy.sh" ]; then
            bash "$SCRIPT_DIR/destroy.sh" --force
        fi
    fi
    
    if [ "$SKIP_TERRAFORM" = false ]; then
        validate_terraform
        run_terraform
        wait_for_vms
    else
        print_info "Skipping Terraform (--skip-terraform specified)"
    fi
    
    if [ "$SKIP_ANSIBLE" = false ]; then
        run_ansible
    else
        print_info "Skipping Ansible (--skip-ansible specified)"
    fi
    
    post_deployment_validation
    show_deployment_summary
    
    echo "=== sit-spark Kubernetes Deployment Completed at $(date) ===" >> "$LOG_FILE"
}

# Run main function
main "$@"