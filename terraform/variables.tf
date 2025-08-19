# Spark Infrastructure Variables

# Proxmox Configuration
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.1.100:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox username"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "spark-hypervisor"
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

# VM Template Configuration
variable "vm_template" {
  description = "VM template name"
  type        = string
  default     = "ubuntu-22.04-cloud-init"
}

# Network Configuration
variable "network_bridge" {
  description = "Network bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_prefix" {
  description = "Network prefix (first three octets)"
  type        = string
  default     = "192.168.1"
}

variable "network_gateway" {
  description = "Network gateway"
  type        = string
  default     = "192.168.1.1"
}

# SSH Configuration
variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

# Kubernetes Master Configuration
variable "k8s_master_count" {
  description = "Number of Kubernetes master nodes"
  type        = number
  default     = 1
}

variable "k8s_master_cores" {
  description = "CPU cores for Kubernetes masters"
  type        = number
  default     = 2
}

variable "k8s_master_memory" {
  description = "Memory for Kubernetes masters (MB)"
  type        = number
  default     = 4096
}

variable "k8s_master_disk_size" {
  description = "Disk size for Kubernetes masters (GB)"
  type        = string
  default     = "50G"
}

# Kubernetes Worker Configuration
variable "k8s_worker_count" {
  description = "Number of Kubernetes worker nodes"
  type        = number
  default     = 2
}

variable "k8s_worker_cores" {
  description = "CPU cores for Kubernetes workers"
  type        = number
  default     = 4
}

variable "k8s_worker_memory" {
  description = "Memory for Kubernetes workers (MB)"
  type        = number
  default     = 8192
}

variable "k8s_worker_disk_size" {
  description = "Disk size for Kubernetes workers (GB)"
  type        = string
  default     = "100G"
}

# Monitoring Configuration
variable "monitoring_count" {
  description = "Number of monitoring nodes"
  type        = number
  default     = 1
}

variable "monitoring_cores" {
  description = "CPU cores for monitoring nodes"
  type        = number
  default     = 2
}

variable "monitoring_memory" {
  description = "Memory for monitoring nodes (MB)"
  type        = number
  default     = 4096
}

variable "monitoring_disk_size" {
  description = "Disk size for monitoring nodes (GB)"
  type        = string
  default     = "100G"
}

# Development Configuration
variable "development_count" {
  description = "Number of development nodes"
  type        = number
  default     = 2
}

variable "development_cores" {
  description = "CPU cores for development nodes"
  type        = number
  default     = 2
}

variable "development_memory" {
  description = "Memory for development nodes (MB)"
  type        = number
  default     = 4096
}

variable "development_disk_size" {
  description = "Disk size for development nodes (GB)"
  type        = string
  default     = "50G"
}
