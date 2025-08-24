# Create cloud-init user-data file for manager
resource "local_file" "cloud_init_user_data_manager" {
  content = templatefile("${path.module}/cloud-init-template.yml", {
    ssh_public_key = var.ssh_public_key
    hostname = "spark-k8s-manager"
  })
  filename = "${path.module}/cloud-init/user-data-k8s-manager.yml"
}

# Create cloud-init user-data files for worker nodes
resource "local_file" "cloud_init_user_data_nodes" {
  count = length(var.node_vm_ids)
  
  content = templatefile("${path.module}/cloud-init-template.yml", {
    ssh_public_key = var.ssh_public_key
    hostname = "spark-k8s-node-${count.index + 1}"
  })
  filename = "${path.module}/cloud-init/user-data-k8s-node-${count.index + 1}.yml"
}

# Kubernetes Manager VM
resource "proxmox_vm_qemu" "k8s_manager" {
  name        = "spark-k8s-manager"
  vmid        = var.manager_vm_id
  target_node = var.proxmox_node

  # VM Configuration
  memory = var.vm_memory
  cpu {
    sockets = 1
    cores   = var.vm_cpu
  }

  # Boot and OS Configuration
  boot    = "order=scsi0"
  scsihw  = "virtio-scsi-pci"
  os_type = "cloud-init"

  # Disks Configuration
  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = var.vm_disk_size
          cache   = "writeback"
          storage = "local"
          format  = "raw"
        }
      }
    }
  }

  # Network Configuration
  network {
    id     = 1
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init Configuration
  clone      = var.vm_template
  full_clone = true
  ciupgrade  = true

  # IP Configuration
  ipconfig0 = "ip=${var.manager_ip}/16,gw=${var.network_gateway}"
  nameserver = var.dns_servers
  skip_ipv6 = true

  # Cloud-init settings
  ciuser     = "ubuntu"
  cipassword = "ubuntu"
  sshkeys    = var.ssh_public_key

  # Additional cloud-init configuration
  cicustom = "user=local:snippets/user-data-k8s-manager.yml"

  # VM Options
  agent   = 1
  onboot  = true
  startup = "order=1"

  tags = "kubernetes,manager"

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  depends_on = [local_file.cloud_init_user_data_manager]
}

# Kubernetes Worker Nodes
resource "proxmox_vm_qemu" "k8s_nodes" {
  count = length(var.node_vm_ids)

  name        = "spark-k8s-node-${count.index + 1}"
  vmid        = var.node_vm_ids[count.index]
  target_node = var.proxmox_node

  # VM Configuration
  memory = var.vm_memory
  cpu {
    sockets = 1
    cores   = var.vm_cpu
  }

  # Boot and OS Configuration
  boot    = "order=scsi0"
  scsihw  = "virtio-scsi-pci"
  os_type = "cloud-init"

  # Disks Configuration
  disks {
    ide {
      ide2 {
        cloudinit {
          storage = "local"
        }
      }
    }
    scsi {
      scsi0 {
        disk {
          size    = var.vm_disk_size
          cache   = "writeback"
          storage = "local"
          format  = "raw"
        }
      }
    }
  }

  # Network Configuration
  network {
    id     = 1
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-init Configuration
  clone      = var.vm_template
  full_clone = true
  ciupgrade  = true

  # IP Configuration
  ipconfig0 = "ip=${var.node_ips[count.index]}/16,gw=${var.network_gateway}"
  nameserver = var.dns_servers
  skip_ipv6 = true

  # Cloud-init settings
  ciuser     = "ubuntu"
  cipassword = "ubuntu"
  sshkeys    = var.ssh_public_key

  # Additional cloud-init configuration
  cicustom = "user=local:snippets/user-data-k8s-node-${count.index + 1}.yml"

  # VM Options
  agent   = 1
  onboot  = true
  startup = "order=2"

  tags = "kubernetes,worker"

  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  depends_on = [proxmox_vm_qemu.k8s_manager, local_file.cloud_init_user_data_nodes]
}
