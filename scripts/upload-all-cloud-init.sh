#!/bin/bash

# Upload all cloud-init configurations to Proxmox
# This script uploads all generated user-data files to Proxmox snippets storage

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

Upload all cloud-init user-data files to Proxmox snippets storage

OPTIONS:
    -h, --help              Show this help message
    -f, --force             Overwrite existing files

EXAMPLES:
    $0                      # Upload all cloud-init files
    $0 --force              # Force overwrite existing files

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

# Function to upload a single cloud-init file
upload_file() {
    local local_file=$1
    local remote_file=$2
    local force_upload=$3
    
    if [ ! -f "$local_file" ]; then
        print_error "Local file not found: $local_file"
        return 1
    fi
    
    # Check if file already exists on Proxmox
    if [ "$force_upload" = false ]; then
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@$PROXMOX_HOST" "test -f /var/lib/vz/snippets/$remote_file" 2>/dev/null; then
            print_warning "File already exists on Proxmox: $remote_file"
            print_info "Use --force to overwrite"
            return 1
        fi
    fi
    
    # Upload the file
    print_info "Uploading: $local_file -> $remote_file"
    if scp -o StrictHostKeyChecking=no "$local_file" "root@$PROXMOX_HOST:/var/lib/vz/snippets/$remote_file"; then
        print_success "Uploaded: $remote_file"
        
        # Set proper permissions
        ssh -o StrictHostKeyChecking=no "root@$PROXMOX_HOST" "chmod 644 /var/lib/vz/snippets/$remote_file"
        
        return 0
    else
        print_error "Failed to upload: $remote_file"
        return 1
    fi
}

# Function to upload all cloud-init files
upload_all_cloud_init() {
    local force_upload=${1:-false}
    
    print_info "Uploading all cloud-init files to Proxmox..."
    
    local upload_count=0
    local error_count=0
    
    # Upload manager cloud-init file
    if [ -f "$TERRAFORM_DIR/cloud-init/user-data-k8s-manager.yml" ]; then
        if upload_file "$TERRAFORM_DIR/cloud-init/user-data-k8s-manager.yml" "user-data-k8s-manager.yml" "$force_upload"; then
            ((upload_count++))
        else
            ((error_count++))
        fi
    else
        print_warning "Manager cloud-init file not found. Run 'terraform plan' first."
    fi
    
    # Upload worker node cloud-init files
    for i in {1..3}; do
        local node_file="$TERRAFORM_DIR/cloud-init/user-data-k8s-node-$i.yml"
        if [ -f "$node_file" ]; then
            if upload_file "$node_file" "user-data-k8s-node-$i.yml" "$force_upload"; then
                ((upload_count++))
            else
                ((error_count++))
            fi
        else
            print_warning "Node $i cloud-init file not found. Run 'terraform plan' first."
        fi
    done
    
    # Summary
    print_info "Upload Summary:"
    print_info "- Successfully uploaded: $upload_count files"
    if [ $error_count -gt 0 ]; then
        print_warning "- Errors/Skipped: $error_count files"
    fi
    
    if [ $upload_count -gt 0 ]; then
        print_success "Cloud-init files uploaded successfully!"
        print_info "You can now run 'terraform apply' to create VMs with the updated configuration"
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
    upload_all_cloud_init "$force_upload"
}

# Run main function
main "$@"