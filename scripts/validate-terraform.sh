#!/bin/bash

# Terraform Infrastructure Validation Script
# This script validates the Terraform infrastructure deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="terraform"
TIMEOUT=300  # 5 minutes timeout for VM readiness

echo -e "${YELLOW}Starting Terraform infrastructure validation...${NC}"

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        return 1
    fi
}

# Function to check if command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed${NC}"
        exit 1
    fi
}

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"
check_command terraform
check_command ping
check_command ssh

# Change to terraform directory
cd "$TERRAFORM_DIR"

# Validate Terraform configuration
echo -e "${YELLOW}Validating Terraform configuration...${NC}"
terraform validate
print_status $? "Terraform configuration is valid"

# Check Terraform state
echo -e "${YELLOW}Checking Terraform state...${NC}"
if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}Error: terraform.tfstate not found. Run 'terraform apply' first.${NC}"
    exit 1
fi

# Get outputs
echo -e "${YELLOW}Retrieving Terraform outputs...${NC}"
MANAGER_IP=$(terraform output -raw manager_ip 2>/dev/null)
NODE_IPS=$(terraform output -json node_ips 2>/dev/null | jq -r '.[]')

if [ -z "$MANAGER_IP" ]; then
    echo -e "${RED}Error: Could not retrieve manager IP from Terraform outputs${NC}"
    exit 1
fi

print_status 0 "Retrieved infrastructure information"
echo "  Manager IP: $MANAGER_IP"
echo "  Node IPs: $(echo $NODE_IPS | tr '\n' ' ')"

# Test network connectivity
echo -e "${YELLOW}Testing network connectivity...${NC}"

# Test manager connectivity
ping -c 3 -W 5 "$MANAGER_IP" > /dev/null 2>&1
print_status $? "Manager ($MANAGER_IP) is reachable"

# Test node connectivity
for ip in $NODE_IPS; do
    ping -c 3 -W 5 "$ip" > /dev/null 2>&1
    print_status $? "Node ($ip) is reachable"
done

# Test SSH connectivity
echo -e "${YELLOW}Testing SSH connectivity...${NC}"

# Wait for SSH to be ready
wait_for_ssh() {
    local ip=$1
    local timeout=$2
    local elapsed=0
    
    while [ $elapsed -lt $timeout ]; do
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$ip 'exit' &>/dev/null; then
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
    done
    return 1
}

# Test manager SSH
wait_for_ssh "$MANAGER_IP" $TIMEOUT
print_status $? "SSH connection to manager ($MANAGER_IP) is working"

# Test node SSH
for ip in $NODE_IPS; do
    wait_for_ssh "$ip" $TIMEOUT
    print_status $? "SSH connection to node ($ip) is working"
done

# Validate VM specifications
echo -e "${YELLOW}Validating VM specifications...${NC}"

validate_vm_specs() {
    local ip=$1
    local vm_type=$2
    
    # Check CPU cores
    cpu_cores=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip 'nproc' 2>/dev/null)
    if [ "$cpu_cores" -ge 4 ]; then
        print_status 0 "$vm_type ($ip) has sufficient CPU cores ($cpu_cores)"
    else
        print_status 1 "$vm_type ($ip) has insufficient CPU cores ($cpu_cores)"
    fi
    
    # Check memory
    memory_gb=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip 'free -g | grep "^Mem:" | awk "{print \$2}"' 2>/dev/null)
    if [ "$memory_gb" -ge 7 ]; then  # Allow for some overhead
        print_status 0 "$vm_type ($ip) has sufficient memory (${memory_gb}GB)"
    else
        print_status 1 "$vm_type ($ip) has insufficient memory (${memory_gb}GB)"
    fi
    
    # Check disk space
    disk_gb=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip 'df -BG / | tail -1 | awk "{print \$2}" | sed "s/G//"' 2>/dev/null)
    if [ "$disk_gb" -ge 45 ]; then  # Allow for some overhead
        print_status 0 "$vm_type ($ip) has sufficient disk space (${disk_gb}GB)"
    else
        print_status 1 "$vm_type ($ip) has insufficient disk space (${disk_gb}GB)"
    fi
}

# Validate manager specs
validate_vm_specs "$MANAGER_IP" "Manager"

# Validate node specs
node_count=1
for ip in $NODE_IPS; do
    validate_vm_specs "$ip" "Node-$node_count"
    node_count=$((node_count + 1))
done

# Check Kubernetes prerequisites
echo -e "${YELLOW}Checking Kubernetes prerequisites...${NC}"

check_k8s_prereqs() {
    local ip=$1
    local vm_type=$2
    
    # Check if swap is disabled
    swap_status=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip 'swapon --show | wc -l' 2>/dev/null)
    if [ "$swap_status" -eq 0 ]; then
        print_status 0 "$vm_type ($ip) has swap disabled"
    else
        print_status 1 "$vm_type ($ip) has swap enabled (should be disabled)"
    fi
    
    # Check if br_netfilter module is loaded
    if ssh -o StrictHostKeyChecking=no ubuntu@$ip 'lsmod | grep br_netfilter' &>/dev/null; then
        print_status 0 "$vm_type ($ip) has br_netfilter module loaded"
    else
        print_status 1 "$vm_type ($ip) missing br_netfilter module"
    fi
    
    # Check IP forwarding
    ip_forward=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip 'sysctl net.ipv4.ip_forward | cut -d= -f2 | tr -d " "' 2>/dev/null)
    if [ "$ip_forward" = "1" ]; then
        print_status 0 "$vm_type ($ip) has IP forwarding enabled"
    else
        print_status 1 "$vm_type ($ip) has IP forwarding disabled"
    fi
}

# Check manager prerequisites
check_k8s_prereqs "$MANAGER_IP" "Manager"

# Check node prerequisites
node_count=1
for ip in $NODE_IPS; do
    check_k8s_prereqs "$ip" "Node-$node_count"
    node_count=$((node_count + 1))
done

echo -e "${GREEN}Terraform infrastructure validation completed successfully!${NC}"
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run Ansible playbooks to install Kubernetes"
echo "2. Configure kubectl access"
echo "3. Deploy applications"

cd - > /dev/null