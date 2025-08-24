#!/bin/bash

# sit-spark Kubernetes Cluster Destruction Script
# This script safely tears down the Kubernetes cluster infrastructure
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
LOG_FILE="$PROJECT_ROOT/destruction.log"

# Default values
FORCE=false
VMS_ONLY=false
SKIP_BACKUP=false
INTERACTIVE=true
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

Safely destroy sit-spark Kubernetes cluster infrastructure

OPTIONS:
    -h, --help              Show this help message
    -f, --force             Skip confirmation prompts (non-interactive mode)
    -v, --verbose           Enable verbose output
    --vms-only              Only destroy VMs, keep Terraform state
    --skip-backup           Skip backup procedures
    --interactive           Enable interactive mode (default)
    --non-interactive       Disable interactive mode

EXAMPLES:
    $0                      # Interactive destruction with backups
    $0 --force              # Non-interactive destruction
    $0 --vms-only           # Only destroy VMs
    $0 --skip-backup --force # Quick destruction without backups

WARNING:
    This script will permanently destroy your Kubernetes cluster and all data.
    Make sure you have backed up any important data before proceeding.

EOF
}

# Function to confirm action
confirm_action() {
    local message="$1"
    local default="${2:-n}"
    
    if [ "$INTERACTIVE" = false ] || [ "$FORCE" = true ]; then
        print_warning "Non-interactive mode: proceeding with $message"
        return 0
    fi
    
    local prompt
    if [ "$default" = "y" ]; then
        prompt="$message [Y/n]: "
    else
        prompt="$message [y/N]: "
    fi
    
    while true; do
        read -p "$prompt" -r response
        response=${response:-$default}
        
        case $response in
            [Yy]|[Yy][Ee][Ss])
                return 0
                ;;
            [Nn]|[Nn][Oo])
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites for destruction..."
    
    local missing_tools=()
    
    # Check required tools
    command -v terraform >/dev/null 2>&1 || missing_tools+=("terraform")
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install the missing tools and try again"
        exit 1
    fi
    
    # Check if Terraform directory exists
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found: $TERRAFORM_DIR"
        exit 1
    fi
    
    print_success "Prerequisites check completed"
}

# Function to show current infrastructure status
show_infrastructure_status() {
    print_info "=== Current Infrastructure Status ==="
    
    cd "$TERRAFORM_DIR"
    
    # Check if Terraform state exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        print_warning "No Terraform state found - infrastructure may not exist"
        return 1
    fi
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_info "Initializing Terraform..."
        terraform init >/dev/null 2>&1
    fi
    
    # Show current resources
    print_info "Current Terraform-managed resources:"
    if terraform show -no-color 2>/dev/null | grep -q "resource"; then
        terraform show -no-color | grep -E "^resource|^  id" | tee -a "$LOG_FILE"
    else
        print_info "No resources found in Terraform state"
    fi
    
    cd "$PROJECT_ROOT"
    return 0
}

# Function to backup cluster data
backup_cluster_data() {
    if [ "$SKIP_BACKUP" = true ]; then
        print_info "Skipping backup procedures (--skip-backup specified)"
        return 0
    fi
    
    print_info "=== Creating Cluster Backup ==="
    
    # Create backup directory
    local backup_dir="$PROJECT_ROOT/backups/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    
    print_info "Backup directory: $backup_dir"
    
    # Try to backup from manager node if accessible
    local manager_ip
    if [ -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        manager_ip=$(grep -E '^manager_ip' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 2>/dev/null || echo "")
        
        if [ -n "$manager_ip" ]; then
            print_info "Attempting to backup cluster data from manager node: $manager_ip"
            
            # Test SSH connectivity
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$manager_ip" "echo 'SSH Ready'" >/dev/null 2>&1; then
                
                # Backup kubeconfig
                if ssh "root@$manager_ip" "test -f /root/.kube/config"; then
                    print_info "Backing up kubeconfig..."
                    scp -o StrictHostKeyChecking=no "root@$manager_ip:/root/.kube/config" "$backup_dir/kubeconfig" 2>/dev/null || true
                fi
                
                # Backup cluster information
                print_info "Backing up cluster information..."
                ssh "root@$manager_ip" "kubectl get nodes -o yaml" > "$backup_dir/nodes.yaml" 2>/dev/null || true
                ssh "root@$manager_ip" "kubectl get pods -A -o yaml" > "$backup_dir/pods.yaml" 2>/dev/null || true
                ssh "root@$manager_ip" "kubectl get svc -A -o yaml" > "$backup_dir/services.yaml" 2>/dev/null || true
                ssh "root@$manager_ip" "kubectl get ingress -A -o yaml" > "$backup_dir/ingress.yaml" 2>/dev/null || true
                
                # Backup persistent volumes
                ssh "root@$manager_ip" "kubectl get pv -o yaml" > "$backup_dir/persistent-volumes.yaml" 2>/dev/null || true
                ssh "root@$manager_ip" "kubectl get pvc -A -o yaml" > "$backup_dir/persistent-volume-claims.yaml" 2>/dev/null || true
                
                print_success "Cluster data backup completed"
            else
                print_warning "Cannot connect to manager node - skipping cluster data backup"
            fi
        fi
    fi
    
    # Backup Terraform state
    print_info "Backing up Terraform state..."
    if [ -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
        cp "$TERRAFORM_DIR/terraform.tfstate" "$backup_dir/terraform.tfstate"
    fi
    if [ -f "$TERRAFORM_DIR/terraform.tfstate.backup" ]; then
        cp "$TERRAFORM_DIR/terraform.tfstate.backup" "$backup_dir/terraform.tfstate.backup"
    fi
    
    # Backup configuration files
    print_info "Backing up configuration files..."
    cp -r "$TERRAFORM_DIR"/*.tf "$backup_dir/" 2>/dev/null || true
    cp "$TERRAFORM_DIR/terraform.tfvars" "$backup_dir/" 2>/dev/null || true
    cp -r "$ANSIBLE_DIR" "$backup_dir/" 2>/dev/null || true
    
    print_success "Backup completed: $backup_dir"
    
    # Create backup summary
    cat << EOF > "$backup_dir/backup_info.txt"
Backup created: $(date)
Cluster: sit-spark Kubernetes
Manager IP: ${manager_ip:-"unknown"}
Terraform Directory: $TERRAFORM_DIR
Ansible Directory: $ANSIBLE_DIR

Files backed up:
$(find "$backup_dir" -type f | sort)
EOF
    
    print_info "Backup summary saved to: $backup_dir/backup_info.txt"
}

# Function to gracefully shutdown cluster services
graceful_cluster_shutdown() {
    print_info "=== Graceful Cluster Shutdown ==="
    
    # Get manager IP
    local manager_ip
    if [ -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        manager_ip=$(grep -E '^manager_ip' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2 2>/dev/null || echo "")
        
        if [ -n "$manager_ip" ]; then
            print_info "Attempting graceful shutdown of cluster services on: $manager_ip"
            
            # Test SSH connectivity
            if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$manager_ip" "echo 'SSH Ready'" >/dev/null 2>&1; then
                
                # Drain and delete nodes
                print_info "Draining worker nodes..."
                ssh "root@$manager_ip" "kubectl get nodes --no-headers | grep -v control-plane | awk '{print \$1}' | xargs -I {} kubectl drain {} --ignore-daemonsets --delete-emptydir-data --force --timeout=60s" 2>/dev/null || true
                
                # Delete ingress resources
                print_info "Cleaning up ingress resources..."
                ssh "root@$manager_ip" "kubectl delete ingress --all -A --timeout=60s" 2>/dev/null || true
                
                # Delete services with LoadBalancer type
                print_info "Cleaning up LoadBalancer services..."
                ssh "root@$manager_ip" "kubectl get svc -A -o jsonpath='{range .items[?(@.spec.type==\"LoadBalancer\")]}{.metadata.namespace}{\" \"}{.metadata.name}{\"\\n\"}{end}' | xargs -r -n2 kubectl delete svc -n" 2>/dev/null || true
                
                # Delete persistent volume claims
                print_info "Cleaning up persistent volume claims..."
                ssh "root@$manager_ip" "kubectl delete pvc --all -A --timeout=60s" 2>/dev/null || true
                
                print_success "Graceful cluster shutdown completed"
            else
                print_warning "Cannot connect to manager node - skipping graceful shutdown"
            fi
        fi
    fi
}

# Function to destroy VMs using Terraform
destroy_vms() {
    print_info "=== Destroying Virtual Machines ==="
    
    cd "$TERRAFORM_DIR"
    
    # Initialize Terraform if needed
    if [ ! -d ".terraform" ]; then
        print_info "Initializing Terraform..."
        terraform init
    fi
    
    # Show destruction plan
    print_info "Generating Terraform destruction plan..."
    if [ "$VERBOSE" = true ]; then
        terraform plan -destroy
    else
        terraform plan -destroy -no-color | tee -a "$LOG_FILE"
    fi
    
    # Confirm destruction
    if ! confirm_action "Proceed with VM destruction?"; then
        print_info "VM destruction cancelled by user"
        cd "$PROJECT_ROOT"
        return 1
    fi
    
    # Destroy infrastructure
    print_info "Destroying VMs with Terraform..."
    if [ "$VERBOSE" = true ]; then
        terraform destroy -auto-approve
    else
        terraform destroy -auto-approve -no-color | tee -a "$LOG_FILE"
    fi
    
    print_success "VM destruction completed"
    cd "$PROJECT_ROOT"
}

# Function to cleanup local files
cleanup_local_files() {
    if [ "$VMS_ONLY" = true ]; then
        print_info "Skipping local file cleanup (--vms-only specified)"
        return 0
    fi
    
    print_info "=== Cleaning Up Local Files ==="
    
    # Confirm cleanup
    if ! confirm_action "Remove Terraform state and local files?"; then
        print_info "Local file cleanup cancelled by user"
        return 0
    fi
    
    # Remove Terraform state files
    print_info "Removing Terraform state files..."
    rm -f "$TERRAFORM_DIR/terraform.tfstate"
    rm -f "$TERRAFORM_DIR/terraform.tfstate.backup"
    rm -rf "$TERRAFORM_DIR/.terraform"
    rm -f "$TERRAFORM_DIR/.terraform.lock.hcl"
    
    # Remove log files
    print_info "Removing deployment log files..."
    rm -f "$PROJECT_ROOT/deployment.log"
    rm -f "$PROJECT_ROOT/validation.log"
    
    # Remove any temporary files
    find "$PROJECT_ROOT" -name "*.tmp" -delete 2>/dev/null || true
    find "$PROJECT_ROOT" -name ".DS_Store" -delete 2>/dev/null || true
    
    print_success "Local file cleanup completed"
}

# Function to verify destruction
verify_destruction() {
    print_info "=== Verifying Destruction ==="
    
    cd "$TERRAFORM_DIR"
    
    # Check if any resources remain
    if terraform show -no-color 2>/dev/null | grep -q "resource"; then
        print_warning "Some resources may still exist:"
        terraform show -no-color | grep -E "^resource|^  id" | tee -a "$LOG_FILE"
        return 1
    else
        print_success "No Terraform-managed resources found"
    fi
    
    # Test connectivity to former VMs
    if [ -f "terraform.tfvars" ]; then
        local manager_ip
        local node_ips
        
        manager_ip=$(grep -E '^manager_ip' "terraform.tfvars" | cut -d'"' -f2 2>/dev/null || echo "")
        node_ips=$(grep -E '^node_ips' "terraform.tfvars" | sed 's/.*\[\(.*\)\].*/\1/' | tr -d '"' | tr ',' ' ' 2>/dev/null || echo "")
        
        local all_ips="$manager_ip $node_ips"
        
        print_info "Testing connectivity to former VM IPs..."
        for ip in $all_ips; do
            if [ -n "$ip" ]; then
                if ssh -o ConnectTimeout=3 -o StrictHostKeyChecking=no -o BatchMode=yes "root@$ip" "echo 'Still accessible'" >/dev/null 2>&1; then
                    print_warning "VM at $ip is still accessible"
                else
                    print_success "VM at $ip is no longer accessible"
                fi
            fi
        done
    fi
    
    cd "$PROJECT_ROOT"
}

# Function to show destruction summary
show_destruction_summary() {
    print_info "=== Destruction Summary ==="
    
    cat << EOF | tee -a "$LOG_FILE"
==========================================
sit-spark Kubernetes Cluster Destruction Summary
==========================================
Destruction completed at: $(date)

Actions performed:
- Cluster data backup: $([ "$SKIP_BACKUP" = true ] && echo "Skipped" || echo "Completed")
- Graceful shutdown: Attempted
- VM destruction: Completed
- Local cleanup: $([ "$VMS_ONLY" = true ] && echo "Skipped" || echo "Completed")

Backup location: $PROJECT_ROOT/backups/
Log file: $LOG_FILE

Next steps:
- Review backup files if needed
- Remove backup files when no longer needed
- Re-run deployment script to recreate cluster

EOF
    
    print_success "Cluster destruction completed successfully!"
}

# Function to handle errors during destruction
handle_destruction_error() {
    print_error "Destruction process encountered an error"
    print_error "Check the log file for details: $LOG_FILE"
    
    print_info "Partial destruction may have occurred. You may need to:"
    print_info "1. Check Proxmox VE for any remaining VMs"
    print_info "2. Manually clean up any remaining resources"
    print_info "3. Review Terraform state for inconsistencies"
    
    exit 1
}

# Main destruction function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -f|--force)
                FORCE=true
                INTERACTIVE=false
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --vms-only)
                VMS_ONLY=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --non-interactive)
                INTERACTIVE=false
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
    echo "=== sit-spark Kubernetes Destruction Started at $(date) ===" > "$LOG_FILE"
    
    print_info "Starting sit-spark Kubernetes cluster destruction"
    print_info "Project root: $PROJECT_ROOT"
    print_info "Log file: $LOG_FILE"
    
    # Show warning
    print_warning "WARNING: This will permanently destroy your Kubernetes cluster!"
    print_warning "All data and configurations will be lost unless backed up."
    
    # Final confirmation
    if ! confirm_action "Are you absolutely sure you want to proceed with destruction?"; then
        print_info "Destruction cancelled by user"
        exit 0
    fi
    
    # Set trap for error handling
    trap handle_destruction_error ERR
    
    # Run destruction steps
    check_prerequisites
    show_infrastructure_status || print_warning "Could not determine current infrastructure status"
    backup_cluster_data
    graceful_cluster_shutdown
    destroy_vms
    cleanup_local_files
    verify_destruction
    show_destruction_summary
    
    echo "=== sit-spark Kubernetes Destruction Completed at $(date) ===" >> "$LOG_FILE"
}

# Run main function
main "$@"