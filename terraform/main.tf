# Create cloud-init user-data file with SSH key
resource "local_file" "cloud_init_user_data" {
  content = templatefile("${path.module}/cloud-init-template.yml", {
    ssh_public_key = var.ssh_public_key
  })
  filename = "${path.module}/cloud-init/user-data-k8s.yml"
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
  ipconfig1 = "ip=${var.manager_ip}/16,gw=${var.network_gateway},ip6=dhcp"
  nameserver = "1.1.1.1 8.8.8.8"
  skip_ipv6 = true

  # Cloud-init settings
  ciuser     = "ubuntu"
  cipassword = "ubuntu"
  sshkeys    = var.ssh_public_key

  # Additional cloud-init configuration
  cicustom = "user=local:snippets/user-data-k8s.yml"

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

  depends_on = [local_file.cloud_init_user_data]
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
  ipconfig1 = "ip=${var.node_ips[count.index]}/16,gw=${var.network_gateway},ip6=dhcp"
  nameserver = "1.1.1.1 8.8.8.8"
  skip_ipv6 = true

  # Cloud-init settings
  ciuser     = "ubuntu"
  cipassword = "ubuntu"
  sshkeys    = var.ssh_public_key

  # Additional cloud-init configuration
  cicustom = "user=local:snippets/user-data-k8s.yml"

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

  depends_on = [proxmox_vm_qemu.k8s_manager, local_file.cloud_init_user_data]
}
