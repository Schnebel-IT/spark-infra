# VM Module Outputs

output "vm_id" {
  description = "ID of the created VM"
  value       = proxmox_vm_qemu.vm.vmid
}

output "vm_name" {
  description = "Name of the created VM"
  value       = proxmox_vm_qemu.vm.name
}

output "ip_address" {
  description = "IP address of the VM"
  value       = var.ip_address
}

output "ssh_host" {
  description = "SSH connection string"
  value       = "ubuntu@${var.ip_address}"
}
