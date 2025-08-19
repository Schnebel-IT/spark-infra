# VM Module for Proxmox
resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.target_node
  clone       = var.template
  
  # VM Configuration
  cores   = var.cores
  sockets = 1
  memory  = var.memory
  
  # Disk Configuration
  disk {
    size    = var.disk_size
    type    = "scsi"
    storage = "local-lvm"
    iothread = 1
    ssd     = 1
  }
  
  # Network Configuration
  network {
    model  = "virtio"
    bridge = var.network_bridge
  }
  
  # Cloud-init Configuration
  os_type    = "cloud-init"
  ciuser     = "ubuntu"
  cipassword = "ubuntu"
  
  ipconfig0 = "ip=${var.ip_address}/24,gw=${var.gateway}"
  
  sshkeys = join("\n", var.ssh_keys)
  
  # Boot Configuration
  boot = "c"
  bootdisk = "scsi0"
  
  # QEMU Agent
  agent = 1
  
  # Tags
  tags = join(",", var.tags)
  
  # Lifecycle
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  
  # Wait for cloud-init to complete
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait"
    ]
    
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = var.ip_address
      timeout     = "5m"
    }
  }
}
