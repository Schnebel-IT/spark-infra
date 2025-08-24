#!/bin/bash

# Upload cloud-init configuration to Proxmox
# This script uploads the user-data file to Proxmox snippets storage

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

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}"
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

Upload cloud-init user-data file to Proxmox snippets storage

OPTIONS:
    -h, --help              Show this help message
    -f, --force             Overwrite existing file

EXAMPLES:
    $0                      # Upload cloud-init file
    $0 --force              # Force overwrite existing file

EOF
}

# Function to extract Proxmox connection details
get_proxmox_details() {
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        print_error "terraform.tfvars not found in $TERRAFORM_DIR"
        exit 1
    fi
    
    PROXMOX_HOST=$(grep -E '^proxmox_api_url' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 | sed 's|https://||' | sed 's|:8006/api2/json||')
    PROXMOX_USER=$(grep -E '^proxmox_user' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    PROXMOX_PASSWORD=$(grep -E '^proxmox_password' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    PROXMOX_NODE=$(grep -E '^proxmox_node' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    
    if [ -z "$PROXMOX_HOST" ] || [ -z "$PROXMOX_USER" ] || [ -z "$PROXMOX_PASSWORD" ] || [ -z "$PROXMOX_NODE" ]; then
        print_error "Could not extract Proxmox connection details from terraform.tfvars"
        exit 1
    fi
    
    print_info "Proxmox Host: $PROXMOX_HOST"
    print_info "Proxmox User: $PROXMOX_USER"
    print_info "Proxmox Node: $PROXMOX_NODE"
}

# Function to upload cloud-init file
upload_cloud_init() {
    local force_upload=${1:-false}
    
    # Check if cloud-init file exists
    if [ ! -f "$TERRAFORM_DIR/cloud-init/user-data-k8s.yml" ]; then
        print_error "Cloud-init file not found: $TERRAFORM_DIR/cloud-init/user-data-k8s.yml"
        print_info "Run 'terraform plan' first to generate the file"
        exit 1
    fi
    
    print_info "Uploading cloud-init file to Proxmox..."
    
    # Check if file already exists on Proxmox
    if [ "$force_upload" = false ]; then
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$PROXMOX_HOST" "test -f /var/lib/vz/snippets/user-data-k8s.yml" 2>/dev/null; then
            print_warning "Cloud-init file already exists on Proxmox"
            print_info "Use --force to overwrite, or remove it manually first"
            return 1
        fi
    fi
    
    # Upload the file
    if scp -o StrictHostKeyChecking=no "$TERRAFORM_DIR/cloud-init/user-data-k8s.yml" "root@$PROXMOX_HOST:/var/lib/vz/snippets/user-data-k8s.yml"; then
        print_success "Cloud-init file uploaded successfully"
        
        # Set proper permissions
        ssh -o StrictHostKeyChecking=no "root@$PROXMOX_HOST" "chmod 644 /var/lib/vz/snippets/user-data-k8s.yml"
        print_success "Permissions set correctly"
        
        # Verify upload
        print_info "Verifying upload..."
        if ssh -o StrictHostKeyChecking=no "root@$PROXMOX_HOST" "test -f /var/lib/vz/snippets/user-data-k8s.yml"; then
            print_success "Upload verification successful"
        else
            print_error "Upload verification failed"
            return 1
        fi
    else
        print_error "Failed to upload cloud-init file"
        return 1
    fi
}

# Main function
main() {
    local force_upload=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                force_upload=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_info "Starting cloud-init upload process"
    
    get_proxmox_details
    upload_cloud_init "$force_upload"
    
    print_success "Cloud-init upload completed successfully!"
    print_info "You can now run 'terraform apply' to create VMs with the updated configuration"
}

# Run main function
main "$@"