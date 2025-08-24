# Kubernetes Manager Outputs
output "manager_vm_id" {
  description = "VM ID of the Kubernetes manager"
  value       = proxmox_vm_qemu.k8s_manager.vmid
}

output "manager_ip" {
  description = "IP address of the Kubernetes manager"
  value       = var.manager_ip
}

output "manager_name" {
  description = "Name of the Kubernetes manager VM"
  value       = proxmox_vm_qemu.k8s_manager.name
}

output "manager_ssh_connection" {
  description = "SSH connection string for the manager"
  value       = "ssh ubuntu@${var.manager_ip}"
}

# Kubernetes Nodes Outputs
output "node_vm_ids" {
  description = "VM IDs of the Kubernetes nodes"
  value       = proxmox_vm_qemu.k8s_nodes[*].vmid
}

output "node_ips" {
  description = "IP addresses of the Kubernetes nodes"
  value       = var.node_ips
}

output "node_names" {
  description = "Names of the Kubernetes node VMs"
  value       = proxmox_vm_qemu.k8s_nodes[*].name
}

output "node_ssh_connections" {
  description = "SSH connection strings for the nodes"
  value       = [for ip in var.node_ips : "ssh ubuntu@${ip}"]
}

# Cluster Information
output "cluster_info" {
  description = "Complete cluster information"
  value = {
    manager = {
      vm_id = proxmox_vm_qemu.k8s_manager.vmid
      ip    = var.manager_ip
      name  = proxmox_vm_qemu.k8s_manager.name
    }
    nodes = [
      for i in range(length(var.node_vm_ids)) : {
        vm_id = proxmox_vm_qemu.k8s_nodes[i].vmid
        ip    = var.node_ips[i]
        name  = proxmox_vm_qemu.k8s_nodes[i].name
      }
    ]
    network = {
      bridge  = var.network_bridge
      gateway = var.network_gateway
    }
  }
}

# Ansible Inventory Output
output "ansible_inventory" {
  description = "Ansible inventory configuration"
  value = {
    k8s_manager = {
      hosts = {
        (var.manager_ip) = {
          ansible_host = var.manager_ip
          ansible_user = "ubuntu"
        }
      }
    }
    k8s_nodes = {
      hosts = {
        for i, ip in var.node_ips : ip => {
          ansible_host = ip
          ansible_user = "ubuntu"
        }
      }
    }
    k8s_cluster = {
      children = ["k8s_manager", "k8s_nodes"]
      vars = {
        ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
        ansible_python_interpreter = "/usr/bin/python3"
      }
    }
  }
}

# Connection Test Commands
output "connection_test_commands" {
  description = "Commands to test VM connectivity"
  value = {
    manager = "ping -c 3 ${var.manager_ip}"
    nodes   = [for ip in var.node_ips : "ping -c 3 ${ip}"]
    ssh_manager = "ssh -o ConnectTimeout=5 ubuntu@${var.manager_ip} 'echo Manager connection successful'"
    ssh_nodes   = [for ip in var.node_ips : "ssh -o ConnectTimeout=5 ubuntu@${ip} 'echo Node connection successful'"]
  }
}