# Proxmox Connection Variables
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
}

variable "proxmox_user" {
  description = "Proxmox username"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
}

# VM Configuration Variables
variable "manager_vm_id" {
  description = "VM ID for Kubernetes manager"
  type        = number
  default     = 2000
}

variable "manager_ip" {
  description = "IP address for Kubernetes manager"
  type        = string
  default     = "10.10.1.1"
}

variable "node_vm_ids" {
  description = "VM IDs for Kubernetes nodes"
  type        = list(number)
  default     = [2001, 2002, 2003]
}

variable "node_ips" {
  description = "IP addresses for Kubernetes nodes"
  type        = list(string)
  default     = ["10.10.1.10", "10.10.1.11", "10.10.1.12"]
}

variable "vm_template" {
  description = "VM template name"
  type        = string
  default     = "ubuntu-24.04-cloudinit"
}

variable "vm_cpu" {
  description = "Number of CPU cores for VMs"
  type        = number
  default     = 4
}

variable "vm_memory" {
  description = "Memory in MB for VMs"
  type        = number
  default     = 8192
}

variable "vm_disk_size" {
  description = "Disk size in GB for VMs"
  type        = string
  default     = "50G"
}

variable "network_bridge" {
  description = "Network bridge for VMs"
  type        = string
  default     = "vmbr2"
}

variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "10.10.0.1"
}

variable "dns_servers" {
  description = "DNS servers for VMs"
  type        = string
  default     = "8.8.8.8 1.1.1.1"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}
