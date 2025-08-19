# VM Module Variables

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "target_node" {
  description = "Proxmox node to deploy the VM on"
  type        = string
}

variable "template" {
  description = "Template to clone from"
  type        = string
}

variable "cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Amount of memory in MB"
  type        = number
  default     = 2048
}

variable "disk_size" {
  description = "Size of the primary disk"
  type        = string
  default     = "20G"
}

variable "network_bridge" {
  description = "Network bridge to connect to"
  type        = string
  default     = "vmbr0"
}

variable "ip_address" {
  description = "Static IP address for the VM"
  type        = string
}

variable "gateway" {
  description = "Network gateway"
  type        = string
}

variable "ssh_keys" {
  description = "List of SSH public keys"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "List of tags for the VM"
  type        = list(string)
  default     = []
}
