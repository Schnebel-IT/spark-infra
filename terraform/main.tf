# Kubernetes Manager VM
resource "proxmox_vm_qemu" "k8s_manager" {
  name        = "k8s-manager"
  vmid        = var.manager_vm_id
  target_node = var.proxmox_node

  # VM Configuration
  cores   = var.vm_cpu
  memory  = var.vm_memory
  sockets = 1

  # Boot and OS Configuration
  boot    = "order=scsi0"
  scsihw  = "virtio-scsi-pci"
  os_type = "cloud-init"

  # Disk Configuration
  disk {
    slot    = "scsi0"
    storage = "local-lvm"
    size    = var.vm_disk_size
    format  = "raw"
    cache   = "writethrough"
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

  # IP Configuration
  ipconfig0 = "ip=${var.manager_ip}/16,gw=${var.network_gateway}"

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
}

# Kubernetes Worker Nodes
resource "proxmox_vm_qemu" "k8s_nodes" {
  count = length(var.node_vm_ids)

  name        = "k8s-node-${count.index + 1}"
  vmid        = var.node_vm_ids[count.index]
  target_node = var.proxmox_node

  # VM Configuration
  cores   = var.vm_cpu
  memory  = var.vm_memory
  sockets = 1

  # Boot and OS Configuration
  boot    = "order=scsi0"
  scsihw  = "virtio-scsi-pci"
  os_type = "cloud-init"

  # Disk Configuration
  disk {
    slot    = "scsi0"
    storage = "local-lvm"
    size    = var.vm_disk_size
    format  = "raw"
    cache   = "writethrough"
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

  # IP Configuration
  ipconfig0 = "ip=${var.node_ips[count.index]}/16,gw=${var.network_gateway}"

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

  depends_on = [proxmox_vm_qemu.k8s_manager]
}
