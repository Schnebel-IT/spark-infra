#!/bin/bash

# Debug cloud-init configuration
# This script helps troubleshoot cloud-init issues

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
Usage: $0 [VM_IP]

Debug cloud-init configuration on a VM

ARGUMENTS:
    VM_IP                   IP address of the VM to debug

EXAMPLES:
    $0 10.10.1.1           # Debug manager VM
    $0 10.10.1.10          # Debug worker node

EOF
}

# Function to test VM connectivity
test_connectivity() {
    local vm_ip=$1
    
    print_info "Testing connectivity to VM: $vm_ip"
    
    # Test ping
    if ping -c 1 -W 3 "$vm_ip" >/dev/null 2>&1; then
        print_success "VM is reachable via ping"
    else
        print_error "VM is not reachable via ping"
        return 1
    fi
    
    # Test SSH port
    if nc -z -w3 "$vm_ip" 22 2>/dev/null; then
        print_success "SSH port (22) is open"
    else
        print_error "SSH port (22) is not accessible"
        return 1
    fi
}

# Function to check cloud-init status via console
check_cloud_init_status() {
    local vm_ip=$1
    
    print_info "Checking cloud-init status on VM: $vm_ip"
    
    # Try to connect and check cloud-init status
    print_info "Attempting to check cloud-init status..."
    print_warning "You may need to use the Proxmox console if SSH is not working"
    
    cat << EOF

=== Manual Debug Commands ===
If you can access the VM console, run these commands:

1. Check cloud-init status:
   sudo cloud-init status --long

2. Check cloud-init logs:
   sudo tail -50 /var/log/cloud-init.log
   sudo tail -50 /var/log/cloud-init-output.log

3. Check SSH service:
   sudo systemctl status ssh
   sudo journalctl -u ssh --no-pager -n 20

4. Check user accounts:
   cat /etc/passwd | grep -E "(ubuntu|root)"
   sudo cat /etc/shadow | grep -E "(ubuntu|root)"

5. Check SSH configuration:
   sudo cat /etc/ssh/sshd_config.d/99-cloud-init.conf
   ls -la /home/ubuntu/.ssh/
   sudo cat /home/ubuntu/.ssh/authorized_keys

6. Test password authentication:
   # Try logging in with: ubuntu / ubuntu

7. Check network configuration:
   ip addr show
   ip route show

EOF
}

# Function to generate new cloud-init with debug info
generate_debug_cloud_init() {
    print_info "Generating debug cloud-init configuration..."
    
    cat << 'EOF' > /tmp/debug-user-data.yml
#cloud-config
# Debug cloud-init configuration

# Enable all logging
output: {all: '| tee -a /var/log/cloud-init-output.log'}

# System updates and packages
package_update: true
package_upgrade: false

packages:
  - openssh-server
  - curl
  - wget

# System configuration
timezone: Europe/Berlin
locale: en_US.UTF-8

# SSH configuration
ssh_pwauth: true
disable_root: false
ssh_deletekeys: false

# User configuration
users:
  - name: ubuntu
    groups: [adm, cdrom, dip, plugdev, lxd, sudo]
    lock_passwd: false
    plain_text_passwd: ubuntu
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
  - name: root
    lock_passwd: false
    plain_text_passwd: ubuntu

# SSH daemon configuration
write_files:
  - path: /etc/ssh/sshd_config.d/99-debug.conf
    content: |
      PasswordAuthentication yes
      PubkeyAuthentication yes
      PermitRootLogin yes
      AuthorizedKeysFile .ssh/authorized_keys
      LogLevel DEBUG
    permissions: '0644'
  - path: /tmp/cloud-init-debug.sh
    content: |
      #!/bin/bash
      echo "=== Cloud-init Debug Info ===" > /tmp/debug-info.txt
      echo "Date: $(date)" >> /tmp/debug-info.txt
      echo "Users:" >> /tmp/debug-info.txt
      cat /etc/passwd | grep -E "(ubuntu|root)" >> /tmp/debug-info.txt
      echo "SSH Config:" >> /tmp/debug-info.txt
      cat /etc/ssh/sshd_config.d/99-debug.conf >> /tmp/debug-info.txt
      echo "Network:" >> /tmp/debug-info.txt
      ip addr show >> /tmp/debug-info.txt
      echo "SSH Service:" >> /tmp/debug-info.txt
      systemctl status ssh >> /tmp/debug-info.txt
    permissions: '0755'

# Commands to run
runcmd:
  - systemctl restart ssh
  - systemctl enable ssh
  - /tmp/cloud-init-debug.sh
  - echo "Cloud-init debug setup completed" >> /var/log/cloud-init-output.log

# No reboot for debugging
power_state:
  mode: poweroff
  delay: "now"
  condition: false
EOF

    print_success "Debug cloud-init configuration created: /tmp/debug-user-data.yml"
    print_info "You can upload this to Proxmox for testing:"
    print_info "scp /tmp/debug-user-data.yml root@YOUR_PROXMOX_IP:/var/lib/vz/snippets/debug-user-data.yml"
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 1
    fi
    
    local vm_ip=$1
    
    print_info "Starting cloud-init debug for VM: $vm_ip"
    
    test_connectivity "$vm_ip" || print_warning "Connectivity issues detected"
    check_cloud_init_status "$vm_ip"
    generate_debug_cloud_init
    
    print_info "Debug process completed"
    print_warning "If SSH still doesn't work, try accessing via Proxmox console"
}

# Run main function
main "$@"